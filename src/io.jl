# IO Functions
# ------------

"""
    unsafe_read(input::IO, output::Ptr{UInt8}, nbytes::Int)::Int

Copy at most `nbytes` from `input` into `output`.

This function is similar to `Base.unsafe_read` but is different in some points:
- It does not throw `EOFError` when it fails to read `nbytes` from `input`.
- It returns the number of bytes written to `output`.
- It does not block if there are buffered data in `input`.
"""
function unsafe_read(input::IO, output::Ptr{UInt8}, nbytes::Integer)
    nbytes = convert(UInt, nbytes)
    p = output
    navail = bytesavailable(input)
    if navail == 0 && nbytes > 0 && !eof(input)
        b = read(input, UInt8)
        unsafe_store!(p, b)
        p += 1
        nbytes -= 1
        navail = bytesavailable(input)
    end
    n = min(navail, nbytes)
    Base.unsafe_read(input, p, n)
    p += n
    return Int(p - output)
end
