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

"""
    position(stream::NoopStream)

Get the current poition of `stream`.

Note that this method may return a wrong position when
- some data have been inserted by `TranscodingStreams.unread`, or
- the position of the wrapped stream has been changed outside of this package.
"""
function Base.position(stream::NoopStream)::Int64
    mode = stream.state.mode
    if !isopen(stream)
        throw_invalid_mode(mode)
    elseif mode === :idle
        return Int64(0)
    elseif has_sharedbuf(stream)
        return position(stream.stream)
    elseif mode === :write
        return position(stream.stream) + buffersize(stream.buffer1)
    else # read
        return position(stream.stream) - buffersize(stream.buffer1)
    end
    @assert false "unreachable"
end

function Base.seek(stream::NoopStream, pos::Integer)
    mode = stream.state.mode
    if mode === :write
        flush_buffer2(stream)
    end
    seek(stream.stream, pos)
    initbuffer!(stream.buffer1)
    return stream
end

function Base.seekstart(stream::NoopStream)
    mode = stream.state.mode
    if mode === :write
        flush_buffer2(stream)
    end
    seekstart(stream.stream)
    initbuffer!(stream.buffer1)
    return stream
end

function Base.seekend(stream::NoopStream)
    mode = stream.state.mode
    if mode === :write
        flush_buffer2(stream)
    end
    seekend(stream.stream)
    initbuffer!(stream.buffer1)
    return stream
end

function Base.write(stream::NoopStream, b::UInt8)::Int
    changemode!(stream, :write)
    if has_sharedbuf(stream)
        # directly write data to the underlying stream
        write(stream.stream, b)
        stream.state.bytes_written_out += 1
    else
        buffer1 = stream.buffer1
        marginsize(buffer1) > 0 || flush_buffer2(stream)
        writebyte!(buffer1, b)
    end
    return 1
end

function Base.unsafe_write(stream::NoopStream, input::Ptr{UInt8}, nbytes::UInt)::Int
    changemode!(stream, :write)
    Int(nbytes) # Error if nbytes > typemax Int
    if has_sharedbuf(stream)
        # directly write data to the underlying stream
        n = Int(unsafe_write(stream.stream, input, nbytes))
        stream.state.bytes_written_out += n
        return n
    end
    buffer = stream.buffer1
    if marginsize(buffer) ≥ nbytes
        copydata!(buffer, input, Int(nbytes))
        return Int(nbytes)
    else
        flush_buffer2(stream)
        # directly write data to the underlying stream
        n = Int(unsafe_write(stream.stream, input, nbytes))
        stream.state.bytes_written_out += n
        return n
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
    buffer = stream.buffer1
    @assert buffer === stream.buffer2
    if mode === :idle
        in = out = 0
    elseif mode === :read
        out = buffer.transcoded - buffersize(buffer)
        if has_sharedbuf(stream)
            in = out
        else
            in = buffer.transcoded
        end
    elseif mode === :write
        out = stream.state.bytes_written_out
        in = out
        if !has_sharedbuf(stream)
            in += buffersize(buffer)
        end
    else
        throw_invalid_mode(mode)
    end
    return Stats(in, out, out, out)
end


# Buffering
# ---------
#
# These methods are overloaded for the `Noop` codec because it has only one
# buffer for efficiency.

function fillbuffer(stream::NoopStream; eager::Bool = false)::Int
    changemode!(stream, :read)
    buffer = stream.buffer1
    @assert buffer === stream.buffer2
    if has_sharedbuf(stream)
        # Delegate the operation when buffers are shared.
        underlying_mode::Symbol = stream.stream.state.mode
        if underlying_mode === :idle || underlying_mode === :read
            return fillbuffer(stream.stream, eager = eager)
        else
            return 0
        end
    end
    nfilled::Int = 0
    while ((!eager && buffersize(buffer) == 0) || (eager && makemargin!(buffer, 0, eager = true) > 0)) && !eof(stream.stream)
        makemargin!(buffer, 1)
        nfilled += readdata!(stream.stream, buffer)
    end
    buffer.transcoded += nfilled
    return nfilled
end

# Empty buffer1 by writing out data.
# `stream` must be in :write mode.
# Ensure there is margin available in buffer1 for at least one byte.
function flush_buffer1(stream::NoopStream)::Nothing
    flush_buffer2(stream)
end

# This is always called after `flush_buffer1(stream)`
function flushuntilend(stream::NoopStream)
    @assert iszero(buffersize(stream.buffer1))
    return
end
