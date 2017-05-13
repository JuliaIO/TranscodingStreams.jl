# Transcoding State
# =================

# Data Layout
# -----------
#
# Buffered data are stored in `data` and two position fields are used to keep
# track of buffered data and margin.
#
#             buffered data     margin
#            |<----------->||<----------->|
#     |......XXXXXXXXXXXXXXX..............|
#     ^      ^              ^             ^
#     1      bufferpos      marginpos     endof(data)
#
#
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
end
