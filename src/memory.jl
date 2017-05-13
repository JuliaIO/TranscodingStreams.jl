# Memory
# ======

immutable Memory
    ptr::Ptr{UInt8}
    size::UInt
end

function Base.length(mem::Memory)
    return mem.size
end
