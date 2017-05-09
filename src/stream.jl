# Transcoding Stream
# ==================

struct TranscodingStream{C<:Codec,S<:IO} <: IO
    # codec object
    codec::C

    # source/sink stream
    stream::S

    # mutable state of the stream
    state::State
end

function TranscodingStream(codec::Codec, stream::IO)
    if !isopen(stream)
        throw(ArgumentError("closed stream"))
    end
    return TranscodingStream(codec, stream, State(16 * 1024))
end

function TranscodingStream(::Type{C}, stream::IO) where C <: Codec
    return TranscodingStream(C(), stream)
end

function Base.show(io::IO, stream::TranscodingStream)
    print(io, summary(stream), "(<mode=$(stream.state.mode)>)")
end

function Base.isopen(stream::TranscodingStream)
    return stream.state.mode != :closed
end

function Base.eof(stream::TranscodingStream)
    state = stream.state
    if state.mode == :init
        return eof(stream.stream)
    elseif state.mode == :read
        return buffersize(state) == 0 && fillbuffer(stream) == 0 && eof(stream.stream)
    elseif state.mode == :write
        return eof(stream.stream)
    elseif state.mode == :closed
        return true
    else
        assert(false)
    end
end

function Base.close(stream::TranscodingStream)
    state = stream.state
    if state.mode == :init
        # pass
    elseif state.mode == :read
        flushbuffer(stream)
        finish(Read, stream.codec, stream.stream)
    elseif state.mode == :write
        flushbuffer(stream)
        finish(Write, stream.codec, stream.stream)
    elseif state.mode == :closed
        # pass
    else
        assert(false)
    end
    close(stream.stream)
    state.mode = :closed
    return
end

function Base.flush(stream::TranscodingStream)
    flushbuffer(stream)
    flush(stream.stream)
    return
end


# Read Functions
# --------------

function Base.read(stream::TranscodingStream, ::Type{UInt8})
    prepare(stream, :read)
    if eof(stream)
        throw(EOFError())
    end
    state = stream.state
    b = state.data[state.bufferpos]
    state.bufferpos += 1
    return b
end

function Base.unsafe_read(stream::TranscodingStream, output::Ptr{UInt8}, nbytes::UInt)
    prepare(stream, :read)
    state = stream.state
    p = output
    p_end = output + nbytes
    while p < p_end && !eof(stream)
        m = min(buffersize(state), nbytes)
        unsafe_copy!(p, bufferptr(state), m)
        p += m
        state.bufferpos += m
    end
    if p < p_end && eof(stream)
        throw(EOFError())
    end
    return
end

function Base.nb_available(stream::TranscodingStream)
    prepare(stream, :read)
    return buffersize(stream.state)
end


# Write Functions
# ---------------

function Base.write(stream::TranscodingStream, b::UInt8)
    prepare(stream, :write)
    state = stream.state
    if marginsize(state) == 0 && flushbuffer(stream) == 0
        return 0
    end
    state.data[state.marginpos] = b
    state.marginpos += 1
    return 1
end

function Base.unsafe_write(stream::TranscodingStream, input::Ptr{UInt8}, nbytes::UInt)
    prepare(stream, :write)
    state = stream.state
    p = input
    p_end = p + nbytes
    while p < p_end
        if marginsize(state) == 0 && flushbuffer(stream) == 0
            break
        end
        m = min(marginsize(state), p_end - p)
        unsafe_copy!(marginptr(state), p, m)
        p += m
        state.marginpos += m
    end
    return Int(p - input)
end


# Buffering
# ---------

function fillbuffer(stream::TranscodingStream)::Int
    state = stream.state
    if state.mode != :read
        return 0
    end
    nfilled = 0
    makemargin!(state, 1)
    while marginsize(state) > 0 && state.proc != PROC_FINISH
        n, code = process(Read, stream.codec, stream.stream, marginptr(state), marginsize(state))
        state.marginpos += n
        state.proc = code
        nfilled += n
    end
    return nfilled
end

function flushbuffer(stream::TranscodingStream)::Int
    state = stream.state
    if state.mode != :write
        return 0
    end
    nflushed = 0
    while buffersize(state) > 0
        n, code = process(Write, stream.codec, stream.stream, bufferptr(state), buffersize(state))
        state.bufferpos += n
        state.proc = code
        nflushed += n
    end
    makemargin!(state, 1)
    return nflushed
end

function prepare(stream::TranscodingStream, mode::Symbol)
    state = stream.state
    if state.mode == :closed
        throw(ArgumentError("closed stream"))
    end
    if state.mode == mode
        return
    end

    # finish
    flushbuffer(stream)
    if state.mode == :init
    elseif state.mode == :read
        finish(Read, stream.codec, stream.stream)
    elseif state.mode == :write
        finish(Write, stream.codec, stream.stream)
    else
        assert(false)
    end

    # start
    if mode == :read
        start(Read, stream.codec, stream.stream)
    elseif mode == :write
        start(Write, stream.codec, stream.stream)
    else
        assert(false)
    end
    state.mode = mode
    return
end
