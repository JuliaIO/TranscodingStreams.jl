function Base.seekend(stream::TranscodingStream)
    @warn """
    generic `seekend` on a `TranscodingStream` will be removed in a future release.
    Please use `skip` with a large number instead.
    """
    mode = stream.state.mode
    if mode == :read
        callstartproc(stream, mode)
        emptybuffer!(stream.buffer1)
        emptybuffer!(stream.buffer2)
    elseif mode === :idle
    else
        throw_invalid_mode(mode)
    end
    seekend(stream.stream)
    return stream
end