# Buffer
# ======

# Data Layout
# -----------
#
# Buffered data are stored in `data` and three position fields are used to keep
# track of marked data, buffered data and margin.
#
#             marked      buffer      margin
#          |<-------->||<-------->||<-------->|
#     |....xxxxxxxxxxxxXXXXXXXXXXXX...........|
#     ^    ^           ^           ^          ^
#     1    markpos     bufferpos   marginpos  endof(data)
#
# `markpos` is positive iff there are marked data; otherwise it is set to zero.
# `markpos` ≤ `bufferpos` ≤ `marginpos` must hold whenever possible.

mutable struct Buffer
    # data and positions (see above)
    data::Vector{UInt8}
    markpos::Int
    bufferpos::Int
    marginpos::Int

    # the number of total bytes passed through this buffer
    total::Int64

    function Buffer(size::Integer)
        return new(Vector{UInt8}(size), 0, 1, 1, 0)
    end

    function Buffer(data::Vector{UInt8})
        return new(data, 0, 1, length(data)+1, 0)
    end
end

function Base.length(buf::Buffer)
    return length(buf.data)
end

function Base.endof(buf::Buffer)
    return buffersize(buf)
end

function Base.getindex(buf::Buffer, i::Integer)
    @boundscheck checkbounds(buf, i)
    @inbounds return buf.data[i+buf.bufferpos-1]
end

function Base.checkbounds(buf::Buffer, i::Integer)
    if !(1 ≤ i ≤ endof(buf))
        throw(BoundsError(buf, i))
    end
end

function Base.getindex(buf::Buffer, r::UnitRange{<:Integer})
    @boundscheck checkbounds(buf, r)
    @inbounds return buf.data[r+buf.bufferpos-1]
end

function Base.checkbounds(buf::Buffer, r::UnitRange{<:Integer})
    if !isempty(r) && !(1 ≤ first(r) && last(r) ≤ endof(buf))
        throw(BoundsError(buf, r))
    end
end

function bufferptr(buf::Buffer)
    return pointer(buf.data, buf.bufferpos)
end

function buffersize(buf::Buffer)
    return buf.marginpos - buf.bufferpos
end

function buffermem(buf::Buffer)
    return Memory(bufferptr(buf), buffersize(buf))
end

function readbyte!(buf::Buffer)
    b = buf.data[buf.bufferpos]
    buf.bufferpos += 1
    return b
end

function writebyte!(buf::Buffer, b::UInt8)
    buf.data[buf.marginpos] = b
    buf.marginpos += 1
    return 1
end

function marginptr(buf::Buffer)
    return pointer(buf.data, buf.marginpos)
end

function marginsize(buf::Buffer)
    return endof(buf.data) - buf.marginpos + 1
end

function marginmem(buf::Buffer)
    return Memory(marginptr(buf), marginsize(buf))
end

function ismarked(buf::Buffer)
    return buf.markpos != 0
end

function mark!(buf::Buffer)
    return buf.markpos = buf.bufferpos
end

function unmark!(buf::Buffer)
    if buf.markpos == 0
        return false
    else
        buf.markpos = 0
        return true
    end
end

function reset!(buf::Buffer)
    if buf.markpos == 0
        throw(ArgumentError("not marked"))
    end
    buf.bufferpos = buf.markpos
    buf.markpos = 0
    return buf.bufferpos
end

# Make margin with ≥`minsize`.
function makemargin!(buf::Buffer, minsize::Integer)
    @assert minsize ≥ 0
    if buffersize(buf) == 0 && buf.markpos == 0
        buf.bufferpos = buf.marginpos = 1
    end
    if marginsize(buf) < minsize
        # shift data to left
        if buf.markpos == 0
            datapos = buf.bufferpos
            datasize = buffersize(buf)
        else
            datapos = buf.markpos
            datasize = buf.marginpos - buf.markpos
        end
        copy!(buf.data, 1, buf.data, datapos, datasize)
        if buf.markpos > 0
            buf.markpos -= datapos - 1
        end
        buf.bufferpos -= datapos - 1
        buf.marginpos -= datapos - 1
    end
    if marginsize(buf) < minsize
        # expand data buffer
        resize!(buf.data, buf.marginpos + minsize - 1)
    end
    @assert marginsize(buf) ≥ minsize
    return marginsize(buf)
end

# Remove all buffered data.
function emptybuffer!(buf::Buffer)
    buf.marginpos = buf.bufferpos
    return buf
end

# Skip `n` bytes in the buffer.
function skipbuffer!(buf::Buffer, n::Integer)
    if n > buffersize(buf)
        throw(ArgumentError("too large skip size"))
    end
    buf.bufferpos += n
    return buf
end

# Notify that `n` bytes are consumed from `buf`.
function consumed!(buf::Buffer, n::Integer)
    buf.bufferpos += n
    return buf
end

# Notify that `n` bytes are supplied to `buf`.
function supplied!(buf::Buffer, n::Integer)
    buf.marginpos += n
    return buf
end

# Discard buffered data and initialize positions.
function initbuffer!(buf::Buffer)
    buf.markpos = 0
    buf.bufferpos = buf.marginpos = 1
    buf.total = 0
    return buf
end

# Copy marked data.
function copymarked(buf::Buffer)
    @assert buf.markpos > 0
    return buf.data[buf.markpos:buf.marginpos-1]
end

# Take the ownership of the marked data.
function takemarked!(buf::Buffer)
    @assert buf.markpos > 0
    sz = buf.marginpos - buf.markpos
    copy!(buf.data, 1, buf.data, buf.markpos, sz)
    initbuffer!(buf)
    return resize!(buf.data, sz)
end

# Copy data from `data` to `buf`.
function copydata!(buf::Buffer, data::Ptr{UInt8}, nbytes::Integer)
    makemargin!(buf, nbytes)
    unsafe_copy!(marginptr(buf), data, nbytes)
    buf.marginpos += nbytes
    return buf
end

# Copy data from `buf` to `data`.
function copydata!(data::Ptr{UInt8}, buf::Buffer, nbytes::Integer)
    # NOTE: It's caller's responsibility to ensure that the buffer has at least
    # nbytes.
    @assert buffersize(buf) ≥ nbytes
    unsafe_copy!(data, bufferptr(buf), nbytes)
    buf.bufferpos += nbytes
    return data
end

# Insert data to the current buffer.
function insertdata!(buf::Buffer, data::Ptr{UInt8}, nbytes::Integer)
    makemargin!(buf, nbytes)
    copy!(buf.data, buf.bufferpos + nbytes, buf.data, buf.bufferpos, buffersize(buf))
    unsafe_copy!(bufferptr(buf), data, nbytes)
    buf.marginpos += nbytes
    return buf
end

# Find the first occurrence of a specific byte.
function findbyte(buf::Buffer, byte::UInt8)
    p = ccall(
        :memchr,
        Ptr{UInt8},
        (Ptr{UInt8}, Cint, Csize_t),
        pointer(buf.data, buf.bufferpos), byte, buffersize(buf))
    if p == C_NULL
        return marginptr(buf)
    else
        return p
    end
end
