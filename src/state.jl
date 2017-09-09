# Transcoding State
# =================

# See docs/src/devnotes.md.
mutable struct State
    # current stream mode
    mode::Symbol

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
