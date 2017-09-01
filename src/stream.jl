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

    function TranscodingStream{C,S}(codec::C, stream::S, state::State) where {C<:Codec,S<:IO}
        if !isopen(stream)
            throw(ArgumentError("closed stream"))
        elseif state.mode != :idle
            throw(ArgumentError("invalid initial mode"))
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
TranscodingStreams.TranscodingStream{CodecZlib.GzipDecompression,IOStream}(<mode=idle>)

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

#=
function TranscodingStream(codec::Codec, stream::TranscodingStream; bufsize::Integer=DEFAULT_BUFFER_SIZE)
    buffer = Buffer(DEFAULT_BUFFER_SIZE)
    return TranscodingStream(codec, stream, State(buffer, stream.state.buffer1))
end
=#

function Base.show(io::IO, stream::TranscodingStream)
    print(io, summary(stream), "(<mode=$(stream.state.mode)>)")
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
    return stream.state.mode != :close && stream.state.mode != :panic
end

function Base.close(stream::TranscodingStream)
    if stream.state.mode != :panic
        changemode!(stream, :close)
    end
    close(stream.stream)
    return nothing
end

function Base.eof(stream::TranscodingStream)
    mode = stream.state.mode
    if mode == :idle
        return eof(stream.stream)
    elseif mode == :read
        return buffersize(stream.state.buffer1) == 0 && fillbuffer(stream) == 0
    elseif mode == :write
        return eof(stream.stream)
    elseif mode == :close
        return true
    elseif mode == :panic
        throw_panic_error()
    else
        assert(false)
    end
end

function Base.ismarked(stream::TranscodingStream)
    checkmode(stream)
    return stream.state.buffer1.markpos != 0
end

function Base.mark(stream::TranscodingStream)
    checkmode(stream)
    return mark!(stream.state.buffer1)
end

function Base.unmark(stream::TranscodingStream)
    checkmode(stream)
    return unmark!(stream.state.buffer1)
end

function Base.reset(stream::TranscodingStream)
    checkmode(stream)
    return reset!(stream.state.buffer1)
end

function Base.skip(stream::TranscodingStream, offset::Integer)
    checkmode(stream)
    if offset < 0
        throw(ArgumentError("negative offset"))
    end
    mode = stream.state.mode
    buffer1 = stream.state.buffer1
    skipped = 0
    if mode == :read
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
        # TODO: support skip in write mode
        throw(ArgumentError("not in read mode"))
    end
    return
end


# Read Functions
# --------------

function Base.read(stream::TranscodingStream, ::Type{UInt8})
    changemode!(stream, :read)
    if eof(stream)
        throw(EOFError())
    end
    return readbyte!(stream.state.buffer1)
end

function Base.readuntil(stream::TranscodingStream, delim::UInt8)
    changemode!(stream, :read)
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
    changemode!(stream, :read)
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
    changemode!(stream, :read)
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
    changemode!(stream, :read)
    return buffersize(stream.state.buffer1)
end

function Base.readavailable(stream::TranscodingStream)
    n = nb_available(stream)
    data = Vector{UInt8}(n)
    unsafe_read(stream, pointer(data), n)
    return data
end

"""
    unread(stream::TranscodingStream, data::Vector{UInt8})

Insert `data` to the current reading position of `stream`.

The next `read(stream, sizeof(data))` call will read data that are just
inserted.
"""
function unread(stream::TranscodingStream, data::Vector{UInt8})
    unsafe_unread(stream, pointer(data), sizeof(data))
end

"""
    unsafe_unread(stream::TranscodingStream, data::Ptr, nbytes::Integer)

Insert `nbytes` pointed by `data` to the current reading position of `stream`.

The data are copied into the internal buffer and hence `data` can be safely used
after the operation without interfering the stream.
"""
function unsafe_unread(stream::TranscodingStream, data::Ptr, nbytes::Integer)
    if nbytes < 0
        throw(ArgumentError("negative nbytes"))
    end
    changemode!(stream, :read)
    insertdata!(stream.state.buffer1, convert(Ptr{UInt8}, data), nbytes)
    return nothing
end


# Write Functions
# ---------------

function Base.write(stream::TranscodingStream, b::UInt8)
    changemode!(stream, :write)
    if marginsize(stream.state.buffer1) == 0 && flushbuffer(stream) == 0
        return 0
    end
    return writebyte!(stream.state.buffer1, b)
end

function Base.unsafe_write(stream::TranscodingStream, input::Ptr{UInt8}, nbytes::UInt)
    changemode!(stream, :write)
    state = stream.state
    buffer1 = state.buffer1
    p = input
    p_end = p + nbytes
    while p < p_end && (marginsize(buffer1) > 0 || flushbuffer(stream) > 0)
        m = min(marginsize(buffer1), p_end - p)
        copydata!(buffer1, p, m)
        p += m
    end
    return Int(p - input)
end

function Base.flush(stream::TranscodingStream)
    checkmode(stream)
    if stream.state.mode == :write
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
    changemode!(stream, :write)
    processall(stream)
    return 0
end


# Utils
# -----

function total_in(stream::TranscodingStream)::Int64
    checkmode(stream)
    state = stream.state
    if state.mode == :read
        return state.buffer2.total
    elseif state.mode == :write
        return state.buffer1.total
    else
        return zero(Int64)
    end
end

function total_out(stream::TranscodingStream)::Int64
    checkmode(stream)
    state = stream.state
    if state.mode == :read
        return state.buffer1.total
    elseif state.mode == :write
        return state.buffer2.total
    else
        return zero(Int64)
    end
end


# Buffering
# ---------

function fillbuffer(stream::TranscodingStream)
    changemode!(stream, :read)
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
                changemode!(stream, :panic)
            end
        end
        makemargin!(buffer2, 1)
        readdata!(stream.stream, buffer2)
        _, Δout = call_process(stream, buffer2, buffer1)
        nfilled += Δout
    end
    return nfilled
end

function flushbuffer(stream::TranscodingStream)
    changemode!(stream, :write)
    nflushed::Int = 0
    makemargin!(stream.state.buffer1, 0)
    while marginsize(stream.state.buffer1) == 0
        nflushed += process_to_write(stream)
    end
    return nflushed
end

function flushbufferall(stream::TranscodingStream)
    @assert stream.state.mode == :write
    nflushed::Int = 0
    while buffersize(stream.state.buffer1) > 0
        nflushed += process_to_write(stream)
    end
    return nflushed
end

function processall(stream::TranscodingStream)
    @assert stream.state.mode == :write
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
            changemode!(stream, :panic)
        end
    end
    buffer2 = stream.state.buffer2
    writebuffer!(stream.stream, buffer2)
    Δin, _ = call_process(stream, buffer1, buffer2)
    makemargin!(buffer1, 0)
    return Δin
end

function call_process(stream::TranscodingStream, inbuf::Buffer, outbuf::Buffer)
    state = stream.state
    input = buffermem(inbuf)
    makemargin!(outbuf, minoutsize(stream.codec, input))
    Δin, Δout, state.code = process(stream.codec, input, marginmem(outbuf), state.error)
    inbuf.bufferpos += Δin
    outbuf.marginpos += Δout
    outbuf.total += Δout
    if state.code == :error
        changemode!(stream, :panic)
    elseif state.code == :ok && Δin == Δout == 0
        # When no progress, expand the output buffer.
        makemargin!(outbuf, max(16, marginsize(outbuf) * 2))
    end
    return Δin, Δout
end


# State Transition
# ----------------

# Change the current mode.
function changemode!(stream::TranscodingStream, newmode::Symbol)
    mode = stream.state.mode
    buffer1 = stream.state.buffer1
    buffer2 = stream.state.buffer2
    transition_error() =
        throw(ArgumentError("cannot change the mode from $(mode) to $(newmode)"))
    if mode == newmode
        # mode does not change
        return
    elseif newmode == :panic
        if !haserror(stream.state.error)
            # set a default error
            stream.state.error[] = ErrorException("unknown error happened while processing data")
        end
        stream.state.mode = newmode
        finalize_codec(stream.codec, stream.state.error)
        throw(stream.state.error[])
    elseif mode == :idle
        if newmode == :read || newmode == :write
            stream.state.code = startproc(stream.codec, newmode, stream.state.error)
            if stream.state.code == :error
                changemode!(stream, :panic)
            end
            stream.state.mode = newmode
            return
        elseif newmode == :close
            stream.state.mode = newmode
            finalize_codec(stream.codec, stream.state.error)
            return
        end
    elseif mode == :read
        if newmode == :idle
            initbuffer!(buffer1)
            initbuffer!(buffer2)
            stream.state.mode = newmode
            return
        elseif newmode == :write
            transition_error()
        elseif newmode == :close
            changemode!(stream, :idle)
            changemode!(stream, :close)
            return
        end
    elseif mode == :write
        if newmode == :idle
            processall(stream)
            initbuffer!(buffer1)
            initbuffer!(buffer2)
            stream.state.mode = newmode
            return
        elseif newmode == :read
            transition_error()
        elseif newmode == :close
            changemode!(stream, :idle)
            changemode!(stream, :close)
            return
        end
    elseif mode == :panic
        throw_panic_error()
    else
        # unreachable
        @assert false
    end
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
