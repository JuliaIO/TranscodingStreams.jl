# Transcoding Stream
# ==================

# Data Flow
# ---------
#
# When reading data (`state.state == :read`):
#   user <--- |state.buffer1| <--- <codec> <--- |state.buffer2| <--- stream
#
# When writing data (`state.state == :write`):
#   user ---> |state.buffer1| ---> <codec> ---> |state.buffer2| ---> stream

struct TranscodingStream{C<:Codec,S<:IO} <: IO
    # codec object
    codec::C

    # source/sink stream
    stream::S

    # mutable state of the stream
    state::State

    function TranscodingStream{C,S}(codec::C, stream::S, state::State) where {C<:Codec,S<:IO}
        if !isopen(stream)
            throw(ArgumentError("closed stream"))
        elseif state.state != :idle
            throw(ArgumentError("invalid initial state"))
        end
        initialize(codec)
        return new(codec, stream, state)
    end
end

function TranscodingStream(codec::C, stream::S, state::State) where {C<:Codec,S<:IO}
    return TranscodingStream{C,S}(codec, stream, state)
end

const DEFAULT_BUFFER_SIZE = 16 * 2^10  # 16KiB

"""
    TranscodingStream(codec::Codec, stream::IO; bufsize::Integer=$(DEFAULT_BUFFER_SIZE))

Create a transcoding stream with `codec` and `stream`.

Examples
--------

```julia
julia> using TranscodingStreams

julia> using CodecZlib

julia> file = open(Pkg.dir("TranscodingStreams", "test", "abra.gzip"));

julia> stream = TranscodingStream(GzipDecompression(), file)
TranscodingStreams.TranscodingStream{CodecZlib.GzipDecompression,IOStream}(<state=idle>)

julia> readstring(stream)
"abracadabra"

```
"""
function TranscodingStream(codec::Codec, stream::IO; bufsize::Integer=DEFAULT_BUFFER_SIZE)
    if bufsize ≤ 0
        throw(ArgumentError("non-positive buffer size"))
    end
    return TranscodingStream(codec, stream, State(bufsize))
end

function Base.show(io::IO, stream::TranscodingStream)
    print(io, summary(stream), "(<state=$(stream.state.state)>)")
end


# Base IO Functions
# -----------------

function Base.open(f::Function, ::Type{T}, args...) where T<:TranscodingStream
    stream = T(open(args...))
    try
        f(stream)
    catch
        rethrow()
    finally
        close(stream)
    end
end

function Base.isopen(stream::TranscodingStream)
    return stream.state.state != :close && stream.state.state != :panic
end

function Base.close(stream::TranscodingStream)
    if stream.state.state != :panic
        changestate!(stream, :close)
    end
    close(stream.stream)
    return nothing
end

function Base.eof(stream::TranscodingStream)
    state = stream.state.state
    if state == :idle
        return eof(stream.stream)
    elseif state == :read
        return buffersize(stream.state.buffer1) == 0 && fillbuffer(stream) == 0
    elseif state == :write
        return eof(stream.stream)
    elseif state == :close
        return true
    elseif state == :panic
        throw_panic_error()
    else
        assert(false)
    end
end

function Base.ismarked(stream::TranscodingStream)
    checkstate(stream)
    return stream.state.buffer1.markpos != 0
end

function Base.mark(stream::TranscodingStream)
    checkstate(stream)
    return mark!(stream.state.buffer1)
end

function Base.unmark(stream::TranscodingStream)
    checkstate(stream)
    return unmark!(stream.state.buffer1)
end

function Base.reset(stream::TranscodingStream)
    checkstate(stream)
    return reset!(stream.state.buffer1)
end

function Base.skip(stream::TranscodingStream, offset::Integer)
    checkstate(stream)
    if offset < 0
        throw(ArgumentError("negative offset"))
    end
    state = stream.state.state
    buffer1 = stream.state.buffer1
    skipped = 0
    if state == :read
        while !eof(stream) && buffersize(buffer1) < offset - skipped
            n = buffersize(buffer1)
            emptybuffer!(buffer1)
            skipped += n
        end
        if eof(stream)
            emptybuffer!(buffer1)
        else
            skipbuffer!(buffer1, offset - skipped)
        end
    else
        # TODO: support skip in write state
        throw(ArgumentError("not in read state"))
    end
    return
end


# Read Functions
# --------------

function Base.read(stream::TranscodingStream, ::Type{UInt8})
    changestate!(stream, :read)
    if eof(stream)
        throw(EOFError())
    end
    return readbyte!(stream.state.buffer1)
end

function Base.readuntil(stream::TranscodingStream, delim::UInt8)
    changestate!(stream, :read)
    buffer1 = stream.state.buffer1
    ret = Vector{UInt8}(0)
    filled = 0
    while !eof(stream)
        pos = findbyte(buffer1, delim)
        if pos == 0
            sz = buffersize(buffer1)
            if length(ret) < filled + sz
                resize!(ret, filled + sz)
            end
        else
            sz = pos - buffer1.bufferpos + 1
            resize!(ret, filled + sz)
        end
        readdata!(buffer1, ret, filled+1, sz)
        filled += sz
        if pos > 0
            break
        end
    end
    return ret
end

function Base.unsafe_read(stream::TranscodingStream, output::Ptr{UInt8}, nbytes::UInt)
    changestate!(stream, :read)
    buffer = stream.state.buffer1
    p = output
    p_end = output + nbytes
    while p < p_end && !eof(stream)
        m = min(buffersize(buffer), p_end - p)
        unsafe_copy!(p, bufferptr(buffer), m)
        p += m
        buffer.bufferpos += m
    end
    if p < p_end && eof(stream)
        throw(EOFError())
    end
    return
end

function Base.readbytes!(stream::TranscodingStream, b::AbstractArray{UInt8}, nb=length(b))
    changestate!(stream, :read)
    filled = 0
    resized = false
    while filled < nb && !eof(stream)
        if length(b) == filled
            resize!(b, min(length(b) * 2, nb))
            resized = true
        end
        filled += unsafe_read(stream, pointer(b, filled+1), min(length(b), nb)-filled)
    end
    if resized
        resize!(b, filled)
    end
    return filled
end

function Base.nb_available(stream::TranscodingStream)
    changestate!(stream, :read)
    return buffersize(stream.state.buffer1)
end


# Write Functions
# ---------------

function Base.write(stream::TranscodingStream, b::UInt8)
    changestate!(stream, :write)
    if marginsize(stream.state.buffer1) == 0 && flushbuffer(stream) == 0
        return 0
    end
    return writebyte!(stream.state.buffer1, b)
end

function Base.unsafe_write(stream::TranscodingStream, input::Ptr{UInt8}, nbytes::UInt)
    changestate!(stream, :write)
    state = stream.state
    buffer1 = state.buffer1
    p = input
    p_end = p + nbytes
    while p < p_end && (marginsize(buffer1) > 0 || flushbuffer(stream) > 0)
        m = min(marginsize(buffer1), p_end - p)
        unsafe_copy!(marginptr(buffer1), p, m)
        p += m
        buffer1.marginpos += m
        buffer1.total += m
    end
    return Int(p - input)
end

function Base.flush(stream::TranscodingStream)
    checkstate(stream)
    if stream.state.state == :write
        flushbufferall(stream)
        writebuffer!(stream.stream, stream.state.buffer2)
    end
    flush(stream.stream)
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
    changestate!(stream, :write)
    processall(stream)
    return 0
end


# Transcode
# ---------

"""
    transcode(codec::Codec, data::Vector{UInt8})::Vector{UInt8}

Transcode `data` by applying `codec`.

Examples
--------

```julia
julia> using CodecZlib

julia> data = Vector{UInt8}("abracadabra");

julia> compressed = transcode(ZlibCompression(), data);

julia> decompressed = transcode(ZlibDecompression(), compressed);

julia> String(decompressed)
"abracadabra"

```
"""
function Base.transcode(codec::Codec, data::Vector{UInt8})
    buffer2 = Buffer(length(data))
    mark!(buffer2)
    stream = TranscodingStream(codec, DevNull, State(Buffer(data), buffer2))
    write(stream, TOKEN_END)
    transcoded = copymarked(buffer2)
    changestate!(stream, :idle)
    return transcoded
end


# Utils
# -----

function total_in(stream::TranscodingStream)::Int64
    checkstate(stream)
    state = stream.state
    if state.state == :read
        return state.buffer2.total
    elseif state.state == :write
        return state.buffer1.total
    else
        return zero(Int64)
    end
end

function total_out(stream::TranscodingStream)::Int64
    checkstate(stream)
    state = stream.state
    if state.state == :read
        return state.buffer1.total
    elseif state.state == :write
        return state.buffer2.total
    else
        return zero(Int64)
    end
end


# Buffering
# ---------

function fillbuffer(stream::TranscodingStream)
    changestate!(stream, :read)
    buffer1 = stream.state.buffer1
    buffer2 = stream.state.buffer2
    nfilled::Int = 0
    while buffersize(buffer1) == 0
        if stream.state.code == :end
            if buffersize(buffer2) == 0 && eof(stream.stream)
                break
            end
            # reset
            stream.state.code = startproc(stream.codec, :read, stream.state.error)
            if stream.state.code == :error
                handle_error(stream)
            end
        end
        makemargin!(buffer2, 1)
        readdata!(stream.stream, buffer2)
        makemargin!(buffer1, clamp(div(length(buffer1), 4), 1, DEFAULT_BUFFER_SIZE * 8))
        Δin, Δout, stream.state.code = process(
            stream.codec, buffermem(buffer2), marginmem(buffer1), stream.state.error)
        buffer2.bufferpos += Δin
        buffer1.marginpos += Δout
        buffer1.total += Δout
        nfilled += Δout
        if stream.state.code == :error
            handle_error(stream)
        end
    end
    return nfilled
end

function flushbuffer(stream::TranscodingStream)
    changestate!(stream, :write)
    nflushed::Int = 0
    makemargin!(stream.state.buffer1, 0)
    while marginsize(stream.state.buffer1) == 0
        nflushed += process_to_write(stream)
    end
    return nflushed
end

function flushbufferall(stream::TranscodingStream)
    @assert stream.state.state == :write
    nflushed::Int = 0
    while buffersize(stream.state.buffer1) > 0
        nflushed += process_to_write(stream)
    end
    return nflushed
end

function processall(stream::TranscodingStream)
    @assert stream.state.state == :write
    while buffersize(stream.state.buffer1) > 0 || stream.state.code != :end
        process_to_write(stream)
    end
    writebuffer!(stream.stream, stream.state.buffer2)
    @assert buffersize(stream.state.buffer1) == buffersize(stream.state.buffer2) == 0
end

function process_to_write(stream::TranscodingStream)
    buffer1 = stream.state.buffer1
    if buffersize(buffer1) > 0 && stream.state.code == :end
        # reset
        stream.state.code = startproc(stream.codec, :write, stream.state.error)
        if stream.state.code == :error
            handle_error(stream)
        end
    end
    buffer2 = stream.state.buffer2
    writebuffer!(stream.stream, buffer2)
    makemargin!(buffer2, clamp(div(length(buffer2), 4), 1, DEFAULT_BUFFER_SIZE * 8))
    Δin, Δout, stream.state.code = process(
        stream.codec, buffermem(buffer1), marginmem(buffer2), stream.state.error)
    buffer1.bufferpos += Δin
    buffer2.marginpos += Δout
    buffer2.total += Δout
    if stream.state.code == :error
        handle_error(stream)
    end
    makemargin!(buffer1, 0)
    return Δin
end


# State Transition
# ----------------

# Change the current state.
function changestate!(stream::TranscodingStream, newstate::Symbol)
    state = stream.state.state
    buffer1 = stream.state.buffer1
    buffer2 = stream.state.buffer2
    if state == newstate
        # state does not change
        return
    elseif state == :idle
        if newstate == :read || newstate == :write
            stream.state.code = startproc(stream.codec, newstate, stream.state.error)
            if stream.state.code == :error
                handle_error(stream)
            end
            stream.state.state = newstate
            return
        elseif newstate == :close
            finalize_codec(stream, :close)
            return
        end
    elseif state == :read
        if newstate == :idle
            initbuffer!(buffer1)
            initbuffer!(buffer2)
            stream.state.state = newstate
            return
        elseif newstate == :write
            changestate!(stream, :idle)
            changestate!(stream, :write)
            return
        elseif newstate == :close
            changestate!(stream, :idle)
            changestate!(stream, :close)
            return
        end
    elseif state == :write
        if newstate == :idle
            processall(stream)
            initbuffer!(buffer1)
            initbuffer!(buffer2)
            stream.state.state = newstate
            return
        elseif newstate == :read
            changestate!(stream, :idle)
            changestate!(stream, :read)
            return
        elseif newstate == :close
            changestate!(stream, :idle)
            changestate!(stream, :close)
            return
        end
    elseif state == :panic
        throw_panic_error()
    else
        # unreachable
        @assert false
    end
end

# Check the current state and throw an exception if needed.
function checkstate(stream::TranscodingStream)
    if stream.state.state == :panic
        throw_panic_error()
    end
end

# Throw an argument error (must be called only when the state is panic).
function throw_panic_error()
    throw(ArgumentError("stream is in unrecoverable error; only isopen and close are callable"))
end


# Error Handler
# -------------

# Handle an error happened while transcoding data.
function handle_error(stream::TranscodingStream)
    if !haserror(stream.state.error)
        # set a generic error
        stream.state.error[] = ErrorException("unknown error happened while processing data")
    end
    finalize_codec(stream, :panic)
    throw(stream.state.error[])
end

# Call the finalize method of the codec.
function finalize_codec(stream::TranscodingStream, newstate::Symbol)
    @assert newstate ∈ (:close, :panic)
    try
        finalize(stream.codec)
    catch
        if stream.state.state == :error && haserror(stream.state.error)
            # throw an exception that happended before
            throw(stream.state.error[])
        else
            rethrow()
        end
    finally
        stream.state.state = newstate
    end
end
