# Transcoding State
# =================

mutable struct State
    # current mode (:init, :read, :write, or :closed)
    mode::Symbol

    # buffered data
    data::Vector{UInt8}

    # the starting position of the buffered data
    position::Int

    # the ending position + 1 of the buffered data
    fposition::Int

    # the last return code of `process`
    proc::ProcCode

    function State(size::Integer)
        @assert size > 0
        return new(:init, Vector{UInt8}(size), 1, 1, PROC_INIT)
    end
end

function bufferptr(state::State)
    return pointer(state.data, state.position)
end

function buffersize(state::State)
    return state.fposition - state.position
end

function isemptybuf(state::State)
    return buffersize(state) == 0
end

function marginptr(state::State)
    return pointer(state.data, state.fposition)
end

function marginsize(state::State)
    return endof(state.data) - state.fposition + 1
end

function isfullbuf(state::State)
    return marginsize(state) == 0
end

function makemargin!(state::State, minsize::Int)::Int
    if buffersize(state) == 0
        state.position = state.fposition = 1
    end
    if marginsize(state) < minsize && state.position > 0
        bufsize = buffersize(state)
        copy!(state.data, 1, state.data, state.position, bufsize)
        state.position = 1
        state.fposition = 1 + bufsize
    end
    if marginsize(state) < minsize
        resize!(state.data, state.fposition + minsize - 1)
    end
    @assert marginsize(state) ≥ minsize
    return marginsize(state)
end
