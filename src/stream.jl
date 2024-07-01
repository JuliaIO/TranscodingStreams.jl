# Transcoding Stream
# ==================

# Data Flow
# ---------
#
# When reading data (`state.mode == :read`):
#   user <--- |state.buffer1| <--- <codec> <--- |state.buffer2| <--- stream
#
# When writing data (`state.mode == :write`):
#   user ---> |state.buffer1| ---> <codec> ---> |state.buffer2| ---> stream

struct TranscodingStream{C<:Codec,S<:IO} <: IO
    # codec object
    codec::C

    # source/sink stream
    stream::S

    # mutable state of the stream
    state::State

    # data buffers
    buffer1::Buffer
    buffer2::Buffer

    function TranscodingStream{C,S}(
            codec::C, stream::S, state::State, initialized::Bool) where {C<:Codec,S<:IO}
        if !isopen(stream)
            throw(ArgumentError("closed stream"))
        elseif state.mode != :idle
            throw(ArgumentError("invalid initial mode"))
        end
        if !initialized
            initialize(codec)
        end
        return new(codec, stream, state, state.buffer1, state.buffer2)
    end
end

function TranscodingStream(codec::C, stream::S, state::State;
                           initialized::Bool=false) where {C<:Codec,S<:IO}
    return TranscodingStream{C,S}(codec, stream, state, initialized)
end

const DEFAULT_BUFFER_SIZE = 16 * 2^10  # 16KiB

function checkbufsize(bufsize::Integer)
    if bufsize ≤ 0
        throw(ArgumentError("non-positive buffer size"))
    end
end

function checksharedbuf(sharedbuf::Bool, stream::IO)
    if sharedbuf && !(stream isa TranscodingStream)
        throw(ArgumentError("invalid stream type for sharedbuf=true"))
    end
end

"""
    TranscodingStream(codec::Codec, stream::IO;
                      bufsize::Integer=$(DEFAULT_BUFFER_SIZE),
                      stop_on_end::Bool=false,
                      sharedbuf::Bool=(stream isa TranscodingStream))

Create a transcoding stream with `codec` and `stream`.

A `TranscodingStream` object wraps an input/output stream object `stream`, and
transcodes the byte stream using `codec`. It is a subtype of `IO` and supports
most of the I/O functions in the standard library.

See the docs (<https://bicycle1885.github.io/TranscodingStreams.jl/stable/>) for
available codecs, examples, and more details of the type.

Arguments
---------

- `codec`:
    The data transcoder. The transcoding stream does the initialization and
    finalization of `codec`. Therefore, a codec object is not reusable once it
    is passed to a transcoding stream.
- `stream`:
    The wrapped stream. It must be opened before passed to the constructor.
- `bufsize`:
    The initial buffer size (the default size is 16KiB). The buffer may be
    extended whenever `codec` requests so.
- `stop_on_end`:
    The flag to stop reading on `:end` return code from `codec`.  The
    transcoded data are readable even after stopping transcoding process.  With
    this flag on, `stream` is not closed when the wrapper stream is closed with
    `close`.  Note that if reading some extra data may be read from `stream` into an
    internal buffer, and thus `stream` must be a `TranscodingStream` object and
    `sharedbuf` must be `true` to reuse `stream`.
- `sharedbuf`:
    The flag to share buffers between adjacent transcoding streams.  The value
    must be `false` if `stream` is not a `TranscodingStream` object.

Examples
--------

```jldoctest
julia> using TranscodingStreams

julia> file = open(joinpath(dirname(dirname(pathof(TranscodingStreams))), "README.md"));

julia> stream = TranscodingStream(Noop(), file);

julia> readline(file)
"TranscodingStreams.jl"

julia> close(stream)
```
"""
function TranscodingStream(codec::Codec, stream::IO;
                           bufsize::Integer=DEFAULT_BUFFER_SIZE,
                           stop_on_end::Bool=false,
                           sharedbuf::Bool=(stream isa TranscodingStream))
    checkbufsize(bufsize)
    checksharedbuf(sharedbuf, stream)
    if sharedbuf
    	# Here, the compiler cannot infer at compile time that the
    	# stream must be a TranscodingStream, so we need to help the
    	# compiler along. See https://github.com/JuliaIO/TranscodingStreams.jl/pull/111
        stream::TranscodingStream
        state = State(Buffer(bufsize), stream.buffer1)
    else
        state = State(bufsize)
    end
    state.stop_on_end = stop_on_end
    return TranscodingStream(codec, stream, state)
end

function Base.show(io::IO, stream::TranscodingStream)
    print(io, summary(stream), "(<mode=$(stream.state.mode)>)")
end

# Split keyword arguments.
@nospecialize
@static if isdefined(Base, :Pairs)
splitkwargs(kwargs::Base.Pairs, ks::Tuple{Vararg{Symbol}}) = splitkwargs(NamedTuple(kwargs), ks)
end
function splitkwargs(kwargs::NamedTuple, ks::Tuple{Vararg{Symbol}})
    non_ks = Base.diff_names(keys(kwargs), ks)
    ks = Base.diff_names(keys(kwargs), non_ks)
    return NamedTuple{ks}(kwargs), NamedTuple{non_ks}(kwargs)
end
function splitkwargs(kwargs, keys)
    hits = []
    others = []
    for kwarg in kwargs
        push!(kwarg[1] ∈ keys ? hits : others, kwarg)
    end
    return hits, others
end
@specialize

# throw ArgumentError that mode is invalid.
throw_invalid_mode(mode) = throw(ArgumentError(string("invalid mode :", mode)))

# Return true if the stream shares buffers with underlying stream
function has_sharedbuf(stream::TranscodingStream)::Bool
    stream.stream isa TranscodingStream && stream.buffer2 === stream.stream.buffer1
end

# Base IO Functions
# -----------------

function Base.open(f::Function, ::Type{T}, args...) where T<:TranscodingStream
    stream = T(open(args...))
    try
        f(stream)
    finally
        close(stream)
    end
end

function Base.isopen(stream::TranscodingStream)
    return stream.state.mode != :close && stream.state.mode != :panic
end

function Base.isreadable(stream::TranscodingStream)::Bool
    mode = stream.state.mode
    (mode === :idle || mode === :read || mode === :stop) && isreadable(stream.stream)
end

function Base.iswritable(stream::TranscodingStream)::Bool
    mode = stream.state.mode
    (mode === :idle || mode === :write) && iswritable(stream.stream)
end

function Base.close(stream::TranscodingStream)
    mode = stream.state.mode
    try
        if mode != :panic
            changemode!(stream, :close)
        end
    finally
        if !stream.state.stop_on_end
            close(stream.stream)
        end
    end
    return nothing
end

function Base.eof(stream::TranscodingStream)
    eof = buffersize(stream.buffer1) == 0
    state = stream.state
    mode = state.mode
    if !(mode === :read || mode === :stop)
        changemode!(stream, :read)
    end
    if eof
        eof = sloweof(stream)
    end
    return eof
end
@noinline function sloweof(stream::TranscodingStream)
    state = stream.state
    mode = state.mode
    @assert mode == :read || mode == :stop
    if mode == :read
        return (buffersize(stream.buffer1) == 0 && fillbuffer(stream) == 0)
    elseif mode == :stop
        return buffersize(stream.buffer1) == 0
    end
    @assert false
end

function Base.ismarked(stream::TranscodingStream)::Bool
    checkmode(stream)
    isopen(stream) && ismarked(stream.buffer1)
end

function Base.mark(stream::TranscodingStream)::Int64
    ready_to_read!(stream)
    mark!(stream.buffer1)
    position(stream)
end

function Base.unmark(stream::TranscodingStream)::Bool
    checkmode(stream)
    isopen(stream) && unmark!(stream.buffer1)
end

function Base.reset(stream::T) where T<:TranscodingStream
    Base.ismarked(stream) || throw(ArgumentError("$T not marked"))
    reset!(stream.buffer1)
    position(stream)
end

"""
    position(stream::TranscodingStream)

Return the number of bytes read from or written to `stream`.

Note that the returned value will be different from that of the underlying
stream wrapped by `stream`.  This is because `stream` buffers some data and the
codec may change the length of data.
"""
function Base.position(stream::TranscodingStream)
    mode = stream.state.mode
    if mode === :idle
        return Int64(0)
    elseif mode === :read || mode === :stop
        return stats(stream).out
    elseif mode === :write
        return stats(stream).in
    else
        throw_invalid_mode(mode)
    end
    @assert false "unreachable"
end


# Seek Operations
# ---------------

function Base.seekstart(stream::TranscodingStream)
    mode = stream.state.mode
    if mode === :read
        callstartproc(stream, mode)
        initbuffer!(stream.buffer1)
        initbuffer!(stream.buffer2)
    elseif mode === :idle
    else
        throw_invalid_mode(mode)
    end
    seekstart(stream.stream)
    return stream
end


# Read Functions
# --------------

# needed for `peek(stream, Char)` to work
function Base.peek(stream::TranscodingStream, ::Type{UInt8})::UInt8
    if eof(stream)
        throw(EOFError())
    end
    buf = stream.buffer1
    return buf.data[buf.bufferpos]
end

function Base.read(stream::TranscodingStream, ::Type{UInt8})::UInt8
    x = peek(stream)
    consumed!(stream.buffer1, 1)
    x
end

function Base.readuntil(stream::TranscodingStream, delim::UInt8; keep::Bool=false)
    ready_to_read!(stream)
    buffer1 = stream.buffer1
    # delay initialization so as to reduce the number of buffer resizes
    local ret::Vector{UInt8}
    filled = 0
    while !eof(stream)
        GC.@preserve buffer1 begin
            p = findbyte(buffer1, delim)
            found = false
            if p < marginptr(buffer1)
                found = true
                sz = Int(p + 1 - bufferptr(buffer1))
                if !keep
                    sz -= 1
                end
            else
                sz = buffersize(buffer1)
            end
        end
        if @isdefined(ret)
            resize!(ret, filled + sz)
        else
            @assert filled == 0
            ret = Vector{UInt8}(undef, sz)
        end
        GC.@preserve ret copydata!(pointer(ret, filled+1), buffer1, sz)
        filled += sz
        if found
            if !keep
                # skip the delimiter
                skipbuffer!(buffer1, 1)
            end
            break
        end
    end
    if !@isdefined(ret)
        # special case: stream is empty
        ret = UInt8[]
    end
    return ret
end

"""
    skip(stream::TranscodingStream, offset)

Read bytes from `stream` until `offset` bytes have been read or `eof(stream)` is reached.

Return `stream`, discarding read bytes.

This function will not throw an `EOFError` if `eof(stream)` is reached before
`offset` bytes can be read.
"""
function Base.skip(stream::TranscodingStream, offset::Integer)
    if offset < 0
        # TODO support negative offset if stream is marked
        throw(ArgumentError("negative offset"))
    end
    ready_to_read!(stream)
    buffer1 = stream.buffer1
    skipped = 0
    while skipped < offset && !eof(stream)
        n = min(buffersize(buffer1), offset - skipped)
        skipbuffer!(buffer1, n)
        skipped += n
    end
    return stream
end

function Base.unsafe_read(stream::TranscodingStream, output::Ptr{UInt8}, nbytes::UInt)
    ready_to_read!(stream)
    buffer = stream.buffer1
    p = output
    p_end = output + nbytes
    while p < p_end && !eof(stream)
        m = min(buffersize(buffer), p_end - p)
        copydata!(p, buffer, m)
        p += m
        GC.safepoint()
    end
    if p < p_end
        throw(EOFError())
    end
    return
end

function Base.readbytes!(stream::TranscodingStream, b::DenseArray{UInt8}, nb=length(b))
    ready_to_read!(stream)
    filled = 0
    resized = false
    while filled < nb && !eof(stream)
        if length(b) == filled
            resize!(b, min(max(length(b) * 2, 8), nb))
            resized = true
        end
        filled += GC.@preserve b unsafe_read(stream, pointer(b, filled+firstindex(b)), min(length(b), nb)-filled)
    end
    if resized
        resize!(b, filled)
    end
    return filled
end

function Base.bytesavailable(stream::TranscodingStream)
    ready_to_read!(stream)
    return buffersize(stream.buffer1)
end

function Base.readavailable(stream::TranscodingStream)
    n = bytesavailable(stream)
    data = Vector{UInt8}(undef, n)
    GC.@preserve data unsafe_read(stream, pointer(data), n)
    return data
end

"""
    unread(stream::TranscodingStream, data::AbstractVector{UInt8})

Insert `data` to the current reading position of `stream`.

The next `read(stream, sizeof(data))` call will read data that are just
inserted.

`data` must not alias any internal buffers in `stream`
"""
function unread(stream::TranscodingStream, data::AbstractVector{UInt8})
    ready_to_read!(stream)
    insertdata!(stream.buffer1, data)
    return nothing
end

"""
    unsafe_unread(stream::TranscodingStream, data::Ptr, nbytes::Integer)

Insert `nbytes` pointed by `data` to the current reading position of `stream`.

The data are copied into the internal buffer and hence `data` can be safely used
after the operation without interfering the stream.

`data` must not alias any internal buffers in `stream`
"""
function unsafe_unread(stream::TranscodingStream, data::Ptr, nbytes::Integer)
    if nbytes < 0
        throw(ArgumentError("negative nbytes"))
    end
    ready_to_read!(stream)
    insertdata!(stream.buffer1, Memory(convert(Ptr{UInt8}, data), UInt(nbytes)))
    return nothing
end

# Ready to read data from the stream.
function ready_to_read!(stream::TranscodingStream)
    mode = stream.state.mode
    if !(mode == :read || mode == :stop)
        changemode!(stream, :read)
    end
    return
end


# Write Functions
# ---------------

# Write nothing.
function Base.write(stream::TranscodingStream)
    changemode!(stream, :write)
    return 0
end

function Base.write(stream::TranscodingStream, b::UInt8)::Int
    changemode!(stream, :write)
    buffer1 = stream.buffer1
    marginsize(buffer1) > 0 || flush_buffer1(stream)
    writebyte!(buffer1, b)
    return 1
end

function Base.unsafe_write(stream::TranscodingStream, input::Ptr{UInt8}, nbytes::UInt)
    changemode!(stream, :write)
    Int(nbytes) # Error if nbytes > typemax Int
    buffer1 = stream.buffer1
    p = input
    p_end = p + nbytes
    while p < p_end
        if marginsize(buffer1) ≤ 0
            flush_buffer1(stream)
        end
        m = min(marginsize(buffer1), p_end - p)
        copydata!(buffer1, p, m)
        p += m
        GC.safepoint()
    end
    return Int(p - input)
end

# A singleton type of end token.
struct EndToken end

"""
A special token indicating the end of data.

`TOKEN_END` may be written to a transcoding stream like `write(stream,
TOKEN_END)`, which will terminate the current transcoding block.

!!! note

    Call `flush(stream)` after `write(stream, TOKEN_END)` to make sure that all
    data are written to the underlying stream.
"""
const TOKEN_END = EndToken()

function Base.write(stream::TranscodingStream, ::EndToken)
    changemode!(stream, :write)
    flush_buffer1(stream)
    flushuntilend(stream)
    return 0
end

function Base.flush(stream::TranscodingStream)
    checkmode(stream)
    if stream.state.mode == :write
        flush_buffer1(stream)
        flush_buffer2(stream)
    end
    flush(stream.stream)
end


# Stats
# -----

"""
I/O statistics.

Its object has four fields:
- `in`: the number of bytes supplied into the stream
- `out`: the number of bytes consumed out of the stream
- `transcoded_in`: the number of bytes transcoded from the input buffer
- `transcoded_out`: the number of bytes transcoded to the output buffer

Note that, since the transcoding stream does buffering, `in` is `transcoded_in +
{size of buffered data}` and `out` is `transcoded_out - {size of buffered
data}`.
"""
struct Stats
    in::Int64
    out::Int64
    transcoded_in::Int64
    transcoded_out::Int64
end

function Base.show(io::IO, stats::Stats)
    println(io, summary(stats), ':')
    println(io, "  in: ", stats.in)
    println(io, "  out: ", stats.out)
    println(io, "  transcoded_in: ", stats.transcoded_in)
      print(io, "  transcoded_out: ", stats.transcoded_out)
end

"""
    stats(stream::TranscodingStream)

Create an I/O statistics object of `stream`.
"""
function stats(stream::TranscodingStream)
    state = stream.state
    mode = state.mode
    buffer1 = stream.buffer1
    buffer2 = stream.buffer2
    if mode === :idle
        transcoded_in = transcoded_out = in = out = 0
    elseif mode === :read || mode === :stop
        transcoded_out = buffer1.transcoded
        out = transcoded_out - buffersize(buffer1)
        if has_sharedbuf(stream)
            transcoded_in = stats(stream.stream).out
            in = transcoded_in
        else
            transcoded_in = buffer2.transcoded
            in = transcoded_in + buffersize(buffer2)
        end
    elseif mode === :write
        transcoded_in = buffer1.transcoded
        out = state.bytes_written_out
        transcoded_out = out
        if !has_sharedbuf(stream)
            transcoded_out += buffersize(buffer2)
        end
        in = transcoded_in + buffersize(buffer1)
    else
        throw_invalid_mode(mode)
    end
    return Stats(in, out, transcoded_in, transcoded_out)
end


# Buffering
# ---------

function fillbuffer(stream::TranscodingStream; eager::Bool = false)
    changemode!(stream, :read)
    buffer1 = stream.buffer1
    buffer2 = stream.buffer2
    nfilled::Int = 0
    while ((!eager && buffersize(buffer1) == 0) || (eager && makemargin!(buffer1, 0, eager = true) > 0)) && stream.state.mode != :stop
        if stream.state.code == :end
            if buffersize(buffer2) == 0 && eof(stream.stream)
                break
            end
            callstartproc(stream, :read)
        end
        makemargin!(buffer2, 1)
        readdata!(stream.stream, buffer2)
        _, Δout = callprocess(stream, buffer2, buffer1)
        nfilled += Δout
    end
    return nfilled
end

# Empty buffer1 by writing out data.
# `stream` must be in :write mode.
# Ensure there is margin available in buffer1 for at least one byte.
function flush_buffer1(stream::TranscodingStream)::Nothing
    state = stream.state
    buffer1 = stream.buffer1
    buffer2 = stream.buffer2
    while buffersize(buffer1) > 0
        if state.code == :end
            callstartproc(stream, :write)
        end
        flush_buffer2(stream)
        callprocess(stream, buffer1, buffer2)
    end
    # move positions to the start of the buffer
    @assert !iszero(makemargin!(buffer1, 0))
    return
end

# This is always called after `flush_buffer1(stream)`
function flushuntilend(stream::TranscodingStream)
    state = stream.state
    buffer1 = stream.buffer1
    buffer2 = stream.buffer2
    @assert buffersize(buffer1) == 0
    @assert stream.state.mode === :write
    while state.code != :end
        flush_buffer2(stream)
        callprocess(stream, buffer1, buffer2)
    end
    flush_buffer2(stream)
    return
end


# Interface to codec
# ------------------

# Call `startproc` with epilogne.
function callstartproc(stream::TranscodingStream, mode::Symbol)
    state = stream.state
    state.code = startproc(stream.codec, mode, state.error)
    if state.code == :error
        changemode!(stream, :panic)
    end
    return
end

# Call `process` with prologue and epilogue.
function callprocess(stream::TranscodingStream, inbuf::Buffer, outbuf::Buffer)
    state = stream.state
    makemargin!(
        outbuf,
        GC.@preserve(inbuf, minoutsize(stream.codec, buffermem(inbuf))),
    )
    Δin::Int, Δout::Int, state.code = GC.@preserve inbuf outbuf process(stream.codec, buffermem(inbuf), marginmem(outbuf), state.error)
    @debug(
        "called process()",
        code = state.code,
        input_size = buffersize(inbuf),
        output_size = marginsize(outbuf),
        input_delta = Δin,
        output_delta = Δout,
    )
    consumed!(inbuf, Δin;
        transcode = !has_sharedbuf(stream) || stream.state.mode === :write,
    ) # inbuf is buffer1 if mode is :write
    supplied!(outbuf, Δout;
        transcode = !has_sharedbuf(stream) || stream.state.mode !== :write,
    ) # outbuf is buffer1 if mode is not :write
    if has_sharedbuf(stream)
        if stream.state.mode === :write
            # this must be updated before throwing any error if outbuf is shared.
            stream.state.bytes_written_out += Δout
        end
    end
    if state.code == :error
        changemode!(stream, :panic)
    elseif state.code == :ok && Δin == Δout == 0
        # When no progress, expand the output buffer.
        makemargin!(outbuf, max(16, marginsize(outbuf) * 2))
    elseif state.code == :end && state.stop_on_end
        if stream.state.mode == :read
            if stream.stream isa TranscodingStream && !has_sharedbuf(stream) && !iszero(buffersize(inbuf))
                # unread data to match behavior if inbuf was shared.
                unread(stream.stream, view(inbuf.data, inbuf.bufferpos:inbuf.marginpos-1))
            end
            changemode!(stream, :stop)
        end
    end
    return Δin, Δout
end


# I/O operations
# --------------

# Read as much data as possbile from `input` to the margin of `output`.
# This function will not block if `input` has buffered data.
function readdata!(input::IO, output::Buffer)::Int
    if input isa TranscodingStream && input.buffer1 === output
        # Delegate the operation to the underlying stream for shared buffers.
        mode::Symbol = input.state.mode
        if mode === :idle || mode === :read
            return fillbuffer(input)
        else
            return 0
        end
    end
    nread::Int = 0
    navail = bytesavailable(input)
    if navail == 0 && marginsize(output) > 0 && !eof(input)
        nread += writebyte!(output, read(input, UInt8))
        navail = bytesavailable(input)
    end
    n = min(navail, marginsize(output))
    GC.@preserve output Base.unsafe_read(input, marginptr(output), n)
    supplied!(output, n)
    nread += n
    return nread
end

# Write all data to `output` from the buffer of `input`.
function flush_buffer2(stream::TranscodingStream)::Nothing
    output = stream.stream
    buffer2 = stream.buffer2
    state = stream.state
    @assert state.mode === :write
    if has_sharedbuf(stream)
        # Delegate the operation to the underlying stream for shared buffers.
        changemode!(output, :write)
        flush_buffer1(output)
    else
        while buffersize(buffer2) > 0
            n::Int = GC.@preserve buffer2 Base.unsafe_write(output, bufferptr(buffer2), buffersize(buffer2))
            n ≤ 0 && error("short write")
            consumed!(buffer2, n)
            state.bytes_written_out += n
            GC.safepoint()
        end
        # move positions to the start of the buffer
        @assert !iszero(makemargin!(buffer2, 0))
        GC.safepoint()
    end
    nothing
end


# Mode Transition
# ---------------

# Change the current mode.
function changemode!(stream::TranscodingStream, newmode::Symbol)
    state = stream.state
    mode = state.mode
    if mode == newmode
        # mode does not change
        return
    elseif newmode == :panic
        if !haserror(state.error)
            set_default_error!(state.error)
        end
        state.mode = newmode
        finalize_codec(stream.codec, state.error)
        throw(state.error[])
    elseif mode == :idle
        if newmode == :read || newmode == :write
            state.code = startproc(stream.codec, newmode, state.error)
            if state.code == :error
                changemode!(stream, :panic)
            end
            state.mode = newmode
            return
        elseif newmode == :close
            state.mode = newmode
            finalize_codec(stream.codec, state.error)
            return
        end
    elseif mode == :read
        if newmode == :close || newmode == :stop
            state.mode = newmode
            finalize_codec(stream.codec, state.error)
            return
        end
    elseif mode == :write
        if newmode == :close
            flush_buffer1(stream)
            flushuntilend(stream)
            state.mode = newmode
            finalize_codec(stream.codec, state.error)
            return
        end
    elseif mode == :stop
        if newmode == :close
            state.mode = newmode
            return
        end
    elseif mode == :panic
        throw_panic_error()
    end
    throw(ArgumentError("cannot change the mode from $(mode) to $(newmode)"))
end

# Check the current mode and throw an exception if needed.
function checkmode(stream::TranscodingStream)
    if stream.state.mode == :panic
        throw_panic_error()
    end
end

# Throw an argument error (must be called only when the mode is panic).
function throw_panic_error()
    throw(ArgumentError("stream is in unrecoverable error; only isopen and close are callable"))
end

# Set a defualt error.
function set_default_error!(error::Error)
    error[] = ErrorException("unknown error happened while processing data")
end

# Call the finalize method of the codec.
function finalize_codec(codec::Codec, error::Error)
    try
        finalize(codec)
    catch
        if haserror(error)
            throw(error[])
        else
            rethrow()
        end
    end
end
