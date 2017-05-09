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

mutable struct State
    # current mode (:init, :read, :write, or :closed)
    mode::Symbol

    # storage for buffering
    data::Vector{UInt8}

    # the starting position of the buffered data
    bufferpos::Int

    # the starting position of the margin
    marginpos::Int

    # the last return code of `process`
    proc::ProcCode

    function State(size::Integer)
        @assert size > 0
        return new(:init, Vector{UInt8}(size), 1, 1, PROC_INIT)
    end
end

function bufferptr(state::State)
    return pointer(state.data, state.bufferpos)
end

function buffersize(state::State)
    return state.marginpos - state.bufferpos
end

function marginptr(state::State)
    return pointer(state.data, state.marginpos)
end

function marginsize(state::State)
    return endof(state.data) - state.marginpos + 1
end

function makemargin!(state::State, minsize::Int)::Int
    if buffersize(state) == 0
        # reset positions
        state.bufferpos = state.marginpos = 1
    end
    if marginsize(state) < minsize && state.bufferpos > 0
        # shift buffered data to left
        bufsize = buffersize(state)
        copy!(state.data, 1, state.data, state.bufferpos, bufsize)
        state.bufferpos = 1
        state.marginpos = 1 + bufsize
    end
    if marginsize(state) < minsize
        # expand data buffer
        resize!(state.data, state.marginpos + minsize - 1)
    end
    @assert marginsize(state) ≥ minsize
    return marginsize(state)
end
