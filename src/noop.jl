# Noop Codec
# ==========

"""
    Noop()

Create a noop codec.

Noop (no operation) is a codec that does nothing. The data read from or written
to the stream are kept as-is without any modification. This is often useful as a
buffered stream or an identity element of a composition of streams.

The implementations are specialized for this codec. For example, a `Noop` stream
uses only one buffer rather than a pair of buffers, which avoids copying data
between two buffers and the throughput will be larger than a naive
implementation.
"""
struct Noop <: Codec end

const NoopStream{S} = TranscodingStream{Noop,S} where S<:IO

"""
    NoopStream(stream::IO)

Create a noop stream.
"""
function NoopStream(stream::IO; kwargs...)
    return TranscodingStream(Noop(), stream; kwargs...)
end

function TranscodingStream(codec::Noop, stream::IO;
                           bufsize::Integer=DEFAULT_BUFFER_SIZE,
                           stop_on_end::Bool=false,
                           sharedbuf::Bool=(stream isa TranscodingStream))
    checkbufsize(bufsize)
    checksharedbuf(sharedbuf, stream)
    if sharedbuf
        buffer = stream.buffer1
    else
        buffer = Buffer(bufsize)
    end
    state = State(buffer, buffer)
    state.stop_on_end = stop_on_end
    return TranscodingStream(codec, stream, state)
end

function Base.position(stream::NoopStream)::Int64
    mode = stream.state.mode
    if has_sharedbuf(stream)
        if mode === :idle || mode === :read || mode === :write
            return position(stream.stream) - stream.state.offset
        else
            throw_invalid_mode(mode)
        end
    else
        buffer1 = stream.buffer1
        if mode === :idle
            return Int64(0)
        elseif mode === :write
            return buffer1.shifted + buffer1.marginpos - 1
        elseif mode === :read
            return buffer1.shifted + buffer1.bufferpos - 1
        else
            throw_invalid_mode(mode)
        end
    end
end

function Base.seek(stream::NoopStream, pos::Integer)
    if has_sharedbuf(stream)
        seek(stream.stream, pos)
    else
        mode = stream.state.mode
        if mode === :write
            flushbuffer(stream)
        end
        seek(stream.stream, pos)
        initbuffer!(stream.buffer1)
        stream.buffer1.shifted = pos
    end
    stream.state.offset = 0
    return stream
end

function Base.seekstart(stream::NoopStream)
    if has_sharedbuf(stream)
        seekstart(stream.stream)
    else
        mode = stream.state.mode
        if mode === :write
            flushbuffer(stream)
        end
        seekstart(stream.stream)
        initbuffer!(stream.buffer1)
    end
    stream.state.offset = 0
    return stream
end

function Base.seekend(stream::NoopStream)
    if has_sharedbuf(stream)
        seekend(stream.stream)
    else
        mode = stream.state.mode
        if mode === :write
            flushbuffer(stream)
        end
        seekend(stream.stream)
        initbuffer!(stream.buffer1)
        stream.buffer1.shifted = position(stream.stream) - stream.state.offset
    end
    return stream
end

function Base.unsafe_write(stream::NoopStream, input::Ptr{UInt8}, nbytes::UInt)
    changemode!(stream, :write)
    if has_sharedbuf(stream)
        return unsafe_write(stream.stream, input, nbytes)
    else
        buffer = stream.buffer1
        if marginsize(buffer) ≥ nbytes
            copydata!(buffer, input, nbytes)
            return Int(nbytes)
        else
            flushbuffer(stream)
            # directly write data to the underlying stream
            n = unsafe_write(stream.stream, input, nbytes)
            buffer.shifted += n
            return n
        end
    end
end

initial_output_size(codec::Noop, input::Memory) = length(input)

function process(codec::Noop, input::Memory, output::Memory, error::Error)
    iszero(length(input)) && return (0, 0, :end)
    n::Int = min(length(input), length(output))
    unsafe_copyto!(output.ptr, input.ptr, n)
    (n, n, :ok)
end

# Stats
# -----

function stats(stream::NoopStream)
    state = stream.state
    mode = state.mode
    if mode === :idle
        consumed = supplied = 0
    elseif mode === :read
        supplied = position(stream.stream) - stream.state.offset
        consumed = position(stream)
    elseif mode === :write
        supplied = position(stream)
        consumed = position(stream.stream) - stream.state.offset
    else
        throw_invalid_mode(mode)
    end
    return Stats(supplied, consumed, supplied, supplied)
end


# Buffering
# ---------
#
# These methods are overloaded for the `Noop` codec because it has only one
# buffer for efficiency.

@noinline function sloweof(stream::NoopStream)::Bool
    changemode!(stream, :read)
    buffer = stream.buffer1
    iszero(buffersize(buffer)) || return false
    # fill buffer1
    eof(stream.stream) && return true
    if !has_sharedbuf(stream)
        makemargin!(buffer, 1)
        navail = bytesavailable(stream.stream)
        if navail == 0
            writebyte!(buffer, read(stream.stream, UInt8))
            navail = bytesavailable(stream.stream)
        end
        n = min(navail, marginsize(buffer))
        if !iszero(n)
            GC.@preserve buffer Base.unsafe_read(stream.stream, marginptr(buffer), n)
            supplied!(buffer, n)
        end
    end
    return false
end

function flushbuffer(stream::NoopStream, all::Bool=false)
    changemode!(stream, :write)
    buffer = stream.buffer1
    @assert buffer === stream.buffer2
    nflushed::Int = 0
    if all
        while buffersize(buffer) > 0
            nflushed += writedata!(stream.stream, buffer)
        end
    else
        nflushed += writedata!(stream.stream, buffer)
        makemargin!(buffer, 0)
    end
    # buffer.transcoded += nflushed
    return nflushed
end

function flushuntilend(stream::NoopStream)
    writedata!(stream.stream, stream.buffer1)
    return
end
