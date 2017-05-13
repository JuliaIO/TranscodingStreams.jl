# Identity Codec
# ==============

struct Identity <: Codec end

function process(::Identity, input::Memory, output::Memory)
    n = Int(min(input.size, output.size))
    unsafe_copy!(output.ptr, input.ptr, n)
    return n, n, ifelse(input.size == 0, :end, :ok)
end
