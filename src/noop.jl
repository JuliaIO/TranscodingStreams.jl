struct Noop <: Codec; end

const NoopStream{S} = TranscodingStream{Noop,S} where S<:IO

function NoopStream(stream::IO; kwargs...)
    return TranscodingStream(Noop(), stream; kwargs...)
end

function TranscodingStream(codec::Noop, stream::IO; bufsize::Integer=DEFAULT_BUFFER_SIZE)
    if bufsize ≤ 0
        throw(ArgumentError("non-positive buffer size"))
    end
    buffer = Buffer(bufsize)
    state = TranscodingStreams.State(buffer, buffer)
    return TranscodingStream(codec, stream, state)
end

function Base.unsafe_read(stream::NoopStream, output::Ptr{UInt8}, nbytes::UInt)
    changestate!(stream, :read)
    buffer = stream.state.buffer1
    p = output
    p_end = output + nbytes
    while p < p_end && !eof(stream)
        if buffersize(buffer) > 0
            m = min(buffersize(buffer), p_end - p)
            unsafe_copy!(p, bufferptr(buffer), m)
            buffer.bufferpos += m
        else
            # directly read data from the underlying stream
            m = p_end - p
            unsafe_read(stream.stream, p, m)
        end
        p += m
    end
    if p < p_end && eof(stream)
        throw(EOFError())
    end
    return
end

function Base.unsafe_write(stream::NoopStream, input::Ptr{UInt8}, nbytes::UInt)
    changestate!(stream, :write)
    buffer = stream.state.buffer1
    if marginsize(buffer) ≥ nbytes
        unsafe_copy!(marginptr(buffer), input, nbytes)
        buffer.marginpos += nbytes
        return Int(nbytes)
    else
        flushbuffer(stream)
        # directly write data to the underlying stream
        return unsafe_write(stream.stream, input, nbytes)
    end
end

function Base.transcode(::Noop, data::Vector{UInt8})
    # Copy data because the caller may expect the return object is not the same
    # as from the input.
    return copy(data)
end


# Buffering
# ---------
#
# These methods are overloaded for the `Noop` codec because it has only one
# buffer for efficiency.

function fillbuffer(stream::NoopStream)
    changestate!(stream, :read)
    buffer = stream.state.buffer1
    @assert buffer === stream.state.buffer2
    nfilled::Int = 0
    while buffersize(buffer) == 0 && !eof(stream.stream)
        makemargin!(buffer, 1)
        n = unsafe_read(stream.stream, marginptr(buffer), marginsize(buffer))
        buffer.marginpos += n
        nfilled += n
    end
    return nfilled
end

function flushbuffer(stream::NoopStream)
    changestate!(stream, :write)
    buffer = stream.state.buffer1
    @assert buffer === stream.state.buffer2
    nflushed::Int = 0
    while buffersize(buffer) > 0
        n = unsafe_write(stream.stream, bufferptr(buffer), buffersize(buffer))
        buffer.bufferpos += n
        nflushed += n
    end
    return nflushed
end

function flushbufferall(stream::NoopStream)
    @assert stream.state.state == :write
    buffer = stream.state.buffer1
    bufsize = buffersize(buffer)
    while buffersize(buffer) > 0
        writebuffer!(stream.stream, buffer)
    end
    return bufsize
end

function processall(stream::NoopStream)
    flushbufferall(stream)
    @assert buffersize(stream.state.buffer1) == 0
end
