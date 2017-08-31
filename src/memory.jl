# Memory
# ======

"""
A contiguous memory.

This type works like a `Vector` method.
"""
struct Memory
    ptr::Ptr{UInt8}
    size::UInt
end

function Memory(data::Vector{UInt8})
    return Memory(pointer(data), sizeof(data))
end

function Base.length(mem::Memory)
    return mem.size
end

function Base.endof(mem::Memory)
    return Int(mem.size)
end

function Base.checkbounds(mem::Memory, i::Integer)
    if !(1 ≤ i ≤ endof(mem))
        throw(BoundsError(mem, i))
    end
end

function Base.getindex(mem::Memory, i::Integer)
    @boundscheck checkbounds(mem, i)
    return unsafe_load(mem.ptr, i)
end

function Base.setindex!(mem::Memory, val::UInt8, i::Integer)
    @boundscheck checkbounds(mem, i)
    return unsafe_store!(mem.ptr, val, i)
end
