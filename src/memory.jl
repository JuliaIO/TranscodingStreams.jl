# Memory
# ======

"""
A contiguous view into other memory.

This type works like a `SubVector` method.
"""
struct Memory # <: AbstractVector{UInt8}
    data::Vector{UInt8}
    first::Int
    size::Int
    function Memory(data::Vector{UInt8})
        return new(data, 1, sizeof(data))
    end
    function Memory(data::Vector{UInt8}, first, length)
        checkbounds(data, first:(first - 1 + length))
        return new(data, first, length)
    end
end
function Memory(data::Base.CodeUnits{UInt8}, args...)
    return Memory(unsafe_wrap(Vector{UInt8}, String(data)), args...)
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
