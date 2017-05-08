function unsafe_read(stream::IO, ptr::Ptr{UInt8}, nbytes::Int)::Int
    nread = 0
    navail = nb_available(stream)
    if navail == 0 && nbytes > 0 && !eof(stream)
        b = read(stream, UInt8)
        unsafe_store!(ptr, b)
        ptr += 1
        nbytes -= 1
        nread += 1
        navail = nb_available(stream)
    end
    n = min(navail, nbytes)
    Base.unsafe_read(stream, ptr, n)
    nread += n
    return nread
end
