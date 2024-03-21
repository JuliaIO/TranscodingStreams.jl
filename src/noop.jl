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
    return TranscodingStream(codec, stream, state; sharedbuf)
end

function Base.seek(stream::NoopStream, pos::Integer)
    mode = stream.state.mode
    if mode === :write
        flushbuffer(stream)
    end
    initbuffer!(stream.buffer1)
    seek(stream.stream, stream.offset + pos)
    stream.state.position = pos
    return stream
end

function Base.seekstart(stream::NoopStream)
    mode = stream.state.mode
    if mode === :write
        flushbuffer(stream)
    end
    initbuffer!(stream.buffer1)
    # use seekstart on underlying stream if possible
    if iszero(stream.offset)
        seekstart(stream.stream)
    else
        seek(stream.stream, stream.offset)
    end
    stream.state.position = 0
    return stream
end

function Base.seekend(stream::NoopStream)
    mode = stream.state.mode
    if mode === :write
        flushbuffer(stream)
    end
    initbuffer!(stream.buffer1)
    seekend(stream.stream)
    p_end::Int64 = position(stream.stream)
    stream.state.position = p_end - stream.offset
    return stream
end

function Base.unsafe_write(stream::NoopStream, input::Ptr{UInt8}, nbytes::UInt)
    changemode!(stream, :write)
    buffer = stream.buffer1
    if marginsize(buffer) ≥ nbytes
        copydata!(buffer, input, nbytes)
        stream.state.position += nbytes
        if stream.sharedbuf
            stream.stream.state.position += nbytes
        end
        return Int(nbytes)
    else
        flushbuffer(stream)
        # directly write data to the underlying stream
        m = unsafe_write(stream.stream, input, nbytes)
        stream.state.position += m
        m
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
    @checkmode (:idle, :read, :write)
    buffer = stream.buffer1
    @assert buffer === stream.buffer2
    if mode == :idle
        consumed = supplied = 0
    elseif mode == :read
        supplied = buffer.transcoded
        consumed = supplied - buffersize(buffer)
    elseif mode == :write
        supplied = buffer.transcoded + buffersize(buffer)
        consumed = buffer.transcoded
    else
        @assert false "unreachable"
    end
    return Stats(consumed, supplied, supplied, supplied)
end


# Buffering
# ---------
#
# These methods are overloaded for the `Noop` codec because it has only one
# buffer for efficiency.

function fillbuffer(stream::NoopStream; eager::Bool = false)
    changemode!(stream, :read)
    buffer = stream.buffer1
    @assert buffer === stream.buffer2
    nfilled::Int = 0
    if stream.stream isa TranscodingStream && buffer === stream.buffer1
        # Delegate the operation when buffers are shared.
        nfilled = fillbuffer(stream.stream, eager = eager)

        return nfilled
    end
    while ((!eager && buffersize(buffer) == 0) || (eager && makemargin!(buffer, 0, eager = true) > 0)) && !eof(stream.stream)
        makemargin!(buffer, 1)
        nfilled += readdata!(stream.stream, buffer)
    end
    buffer.transcoded += nfilled
    return nfilled
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
    buffer.transcoded += nflushed
    return nflushed
end

function flushuntilend(stream::NoopStream)
    stream.buffer1.transcoded += writedata!(stream.stream, stream.buffer1)
    return
end
