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

function Base.readbytes!(stream::TranscodingStream, b::DenseArray{UInt8}, nb=length(b))
    filled = 0
    resized = false
    while !eof(stream) && filled < nb
        if length(b) == filled
            resize!(b, min(max(length(b) * 2, 8), nb))
            resized = true
        end
        filled += GC.@preserve b unsafe_read(stream, pointer(b, filled+firstindex(b)), min(length(b), nb)-filled)
    end
    if resized
        resize!(b, filled)
    end
    return filled
end

function Base.readavailable(stream::TranscodingStream)
    n = bytesavailable(stream)
    data = Vector{UInt8}(undef, n)
    GC.@preserve data unsafe_read(stream, pointer(data), n)
    return data
end

"""
    unread(stream::TranscodingStream, data::Vector{UInt8})

Insert `data` to the current reading position of `stream`.

The next `read(stream, sizeof(data))` call will read data that are just
inserted.
"""
function unread(stream::TranscodingStream, data::ByteData)
    GC.@preserve data unsafe_unread(stream, pointer(data), sizeof(data))
end