# Identity Codec
# ==============

struct Identity <: Codec end

function process(::Type{ReadMode}, ::Identity, stream::IO, data::Ptr{UInt8}, nbytes::Int)::Tuple{Int,ProcCode}
    n = unsafe_read(stream, data, nbytes)
    if eof(stream)
        return n, PROC_FINISH
    else
        return n, PROC_OK
    end
end

function process(::Type{WriteMode}, ::Identity, stream::IO, data::Ptr{UInt8}, nbytes::Int)::Tuple{Int,ProcCode}
    n = unsafe_write(stream, data, nbytes)
    return Int(n), PROC_OK
end
