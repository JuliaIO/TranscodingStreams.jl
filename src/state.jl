# Transcoding State
# =================

# See docs/src/devnotes.md.
"""
A mutable state type of transcoding streams.

See Developer's notes for details.
"""
mutable struct State
    # current stream mode
    mode::Symbol  # {:idle, :read, :write, :stop, :close, :panic}

    # return code of the last method call
    code::Symbol  # {:ok, :end, :error}

    # flag to go :stop on :end while reading
    stop_on_end::Bool

    # exception thrown while data processing
    error::Error

    # data buffers
    buffer1::Buffer
    buffer2::Buffer

    function State(buffer1::Buffer, buffer2::Buffer)
        return new(:idle, :ok, false, Error(), buffer1, buffer2)
    end
end

function State(size::Integer)
    return State(Buffer(size), Buffer(size))
end
