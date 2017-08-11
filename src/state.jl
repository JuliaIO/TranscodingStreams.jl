# Transcoding State
# =================

"""
Stream state.

A state will be one of the following states:

- `:idle` : initial and intermediate state, no buffered data.
- `:read` : ready to read data, data may be buffered.
- `:write`: ready to write data, data may be buffered.
- `:close`: closed, no buffered data.
- `:panic`: an exception has been thrown in codec, data may be buffered but we
            cannot do anything.
"""
mutable struct State
    # current stream state
    state::Symbol

    # return code of the last method call (:ok or :end)
    code::Symbol

    # exception thrown while data processing
    error::Error

    # data buffers
    buffer1::Buffer
    buffer2::Buffer

    function State(size::Integer)
        return new(:idle, :ok, Error(), Buffer(size), Buffer(size))
    end

    function State(buffer1::Buffer, buffer2::Buffer)
        return new(:idle, :ok, Error(), buffer1, buffer2)
    end
end
