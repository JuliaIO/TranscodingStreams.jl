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
function unsafe_read(input::IO, output::Ptr{UInt8}, nbytes::Int)::Int
    nread = 0
    navail = nb_available(input)
    if navail == 0 && nbytes > 0 && !eof(input)
        b = read(input, UInt8)
        unsafe_store!(output, b)
        output += 1
        nbytes -= 1
        nread += 1
        navail = nb_available(input)
    end
    n = min(navail, nbytes)
    Base.unsafe_read(input, output, n)
    nread += n
    return nread
end

function unsafe_read(input::IO, mem::Memory)
    return unsafe_read(input, mem.ptr, Int(mem.size))
end

function unsafe_write(output::IO, ptr::Ptr{UInt8}, nbytes::Int)::Int
    return Base.unsafe_write(output, ptr, nbytes)
end

function unsafe_write(output::IO, mem::Memory)
    return Base.unsafe_write(output, mem.ptr, mem.size)
end
