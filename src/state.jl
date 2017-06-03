# Transcoding State
# =================

# Stream States
# -------------
#
# - idle  : initial and intermediate state, no buffered data.
# - read  : ready to read data, data may be buffered.
# - write : ready to write data, data may be buffered.
# - close : closed, no buffered data.

mutable struct State
    # current stream state (:idle, :read, :write, or :close)
    state::Symbol

    # return code of the last method call (:ok or :end)
    code::Symbol

    # data buffers
    buffer1::Buffer
    buffer2::Buffer

    function State(size::Integer)
        return new(:idle, :ok, Buffer(size), Buffer(size))
    end

    function State(buffer1::Buffer, buffer2::Buffer)
        return new(:idle, :ok, buffer1, buffer2)
    end
end
