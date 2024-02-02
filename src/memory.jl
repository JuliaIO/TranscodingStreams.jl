# Memory
# ======

"""
A contiguous view into other memory.

This type works like a `SubVector` method.
"""
struct Memory # <: AbstractVector{UInt8}
    # n.b. In Julia v1.11, we could replace this whole struct with a Memory{UInt8} object, possibly with the owner field set
    # but it might cost an extra allocation to gc-track that arrangement
    data::ByteData
    first::Int
    size::Int
    function Memory(data::ByteData)
        return new(data, 1, sizeof(data))
    end
    function Memory(data::ByteData, first, length)
        checkbounds(data, first:(first - 1 + length))
        return new(data, first, length)
    end
end

@inline function Base.getproperty(mem::Memory, field::Symbol)
    field === :ptr && return pointer(getfield(mem, :data), getfield(mem, :first))
    return getfield(mem, field)
end
Base.length(mem::Memory) = mem.size % UInt
Base.sizeof(mem::Memory) = mem.size
Base.lastindex(mem::Memory) = mem.size

function Base.checkbounds(mem::Memory, i::Integer)
    if !(1 ≤ i ≤ lastindex(mem))
        throw(BoundsError(mem, i))
    end
end

Base.getindex(mem::Memory, i::Integer) = mem.data[i]
Base.setindex!(mem::Memory, val::UInt8, i::Integer) = (mem.data[i] = val; mem)
