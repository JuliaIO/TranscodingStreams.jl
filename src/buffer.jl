# Buffer
# ======

# Data Layout
# -----------
#
# Buffered data are stored in `data` and three position fields are used to keep
# track of marked data, buffered data and margin.
#
#                     marked      buffer      margin
#                  |<-------->||<-------->||<-------->|
#       data   ....xxxxxxxxxxxxXXXXXXXXXXXX............
#              ^   ^           ^           ^          ^
#   position   1   markpos     bufferpos   marginpos  lastindex(data)
#
# `markpos` is positive iff there are marked data; otherwise it is set to zero.
# `markpos` ≤ `bufferpos` ≤ `marginpos` must hold whenever possible.

mutable struct Buffer
    # data and positions (see above)
    data::Vector{UInt8}
    markpos::Int
    bufferpos::Int
    marginpos::Int

    # the total number of transcoded bytes
    transcoded::Int64

    function Buffer(data::Vector{UInt8}, marginpos::Integer=length(data)+1)
        @assert 1 <= marginpos <= length(data)+1
        return new(data, 0, 1, marginpos, 0)
    end
end

function Buffer(size::Integer = 0)
    return Buffer(Vector{UInt8}(undef, size), 1)
end

function Buffer(data::Base.CodeUnits{UInt8}, args...)
    return Buffer(Vector{UInt8}(data), args...)
end

function Base.length(buf::Buffer)
    return length(buf.data)
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

function marginptr(buf::Buffer)
    return pointer(buf.data, buf.marginpos)
end

function marginsize(buf::Buffer)
    return lastindex(buf.data) - buf.marginpos + 1
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
    @assert buf.markpos > 0
    buf.bufferpos = buf.markpos
    buf.markpos = 0
    return buf.bufferpos
end

# Notify that `n` bytes are consumed from `buf`.
function consumed!(buf::Buffer, n::Integer; transcode::Bool = false)
    buf.bufferpos += n
    if transcode
        buf.transcoded += n
    end
    return buf
end

# Notify that `n` bytes are supplied to `buf`.
function supplied!(buf::Buffer, n::Integer; transcode::Bool = false)
    buf.marginpos += n
    if transcode
        buf.transcoded += n
    end
    return buf
end

# Discard buffered data and initialize positions.
function initbuffer!(buf::Buffer)
    buf.markpos = buf.transcoded = 0
    buf.bufferpos = buf.marginpos = 1
    return buf
end

# Remove all buffered data.
function emptybuffer!(buf::Buffer)
    buf.marginpos = buf.bufferpos
    return buf
end

# Make margin with ≥`minsize` and return the size of it.
# If eager is true, it tries to move data even when the buffer has enough margin.
function makemargin!(buf::Buffer, minsize::Integer; eager::Bool = false)
    @assert minsize ≥ 0
    if buffersize(buf) == 0 && buf.markpos == 0
        buf.bufferpos = buf.marginpos = 1
    end
    if marginsize(buf) < minsize || eager
        # datapos refer to the leftmost position of data that must not be
        # discarded. We can left-shift to discard all data before this
        if buf.markpos == 0
            # If data is not marked we must not discard buffered (nonconsumed) data
            datapos = buf.bufferpos
            datasize = buffersize(buf)
        else
            # Else, we must not consume marked data
            # (Since markpos ≤ bufferpos, we do not consume buffered data either) 
            datapos = buf.markpos
            datasize = buf.marginpos - buf.markpos
        end
        # Shift data left in buffer to make space for new data
        copyto!(buf.data, 1, buf.data, datapos, datasize)
        shift = datapos - 1
        if buf.markpos > 0
            buf.markpos -= shift
        end
        buf.bufferpos -= shift
        buf.marginpos -= shift
    end
    # If there is still not enough margin, we expand buffer.
    # At least enough for minsize, but otherwise 1.5 times
    if marginsize(buf) < minsize
        datasize = length(buf.data)
        resize!(buf.data, max(buf.marginpos + minsize - 1, datasize + div(datasize, 2)))
    end
    @assert marginsize(buf) ≥ minsize
    return marginsize(buf)
end

# Read a byte.
function readbyte!(buf::Buffer)
    b = buf.data[buf.bufferpos]
    consumed!(buf, 1)
    return b
end

# Write a byte.
function writebyte!(buf::Buffer, b::UInt8)
    buf.data[buf.marginpos] = b
    supplied!(buf, 1)
    return 1
end

# Skip `n` bytes in the buffer.
function skipbuffer!(buf::Buffer, n::Integer)
    @assert n ≤ buffersize(buf)
    consumed!(buf, n)
    return buf
end

# Copy data from `data` to `buf`.
function copydata!(buf::Buffer, data::Ptr{UInt8}, nbytes::Integer)
    makemargin!(buf, nbytes)
    GC.@preserve buf unsafe_copyto!(marginptr(buf), data, nbytes)
    supplied!(buf, nbytes)
    return buf
end

# Copy data from `buf` to `data`.
function copydata!(data::Ptr{UInt8}, buf::Buffer, nbytes::Integer)
    # NOTE: It's caller's responsibility to ensure that the buffer has at least
    # nbytes.
    @assert buffersize(buf) ≥ nbytes
    GC.@preserve buf unsafe_copyto!(data, bufferptr(buf), nbytes)
    consumed!(buf, nbytes)
    return data
end

# Insert data to the current buffer.
function insertdata!(buf::Buffer, data::Ptr{UInt8}, nbytes::Integer)
    makemargin!(buf, nbytes)
    copyto!(buf.data, buf.bufferpos + nbytes, buf.data, buf.bufferpos, buffersize(buf))
    GC.@preserve buf unsafe_copyto!(bufferptr(buf), data, nbytes)
    supplied!(buf, nbytes)
    return buf
end

# Find the first occurrence of a specific byte.
function findbyte(buf::Buffer, byte::UInt8)
    p = GC.@preserve buf ccall(
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
