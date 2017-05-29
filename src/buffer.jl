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
    data::Vector{UInt8}
    markpos::Int
    bufferpos::Int
    marginpos::Int

    function Buffer(size::Integer)
        @assert size > 0
        return new(Vector{UInt8}(size), 0, 1, 1)
    end
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
    if buffersize(buf) == 0
        if buf.markpos == 0
            buf.bufferpos = buf.marginpos = 1
        else
            buf.bufferpos = buf.marginpos = buf.markpos
        end
    end
    if marginsize(buf) < minsize
        # shift data to left
        if buf.markpos == 0
            datapos = buf.bufferpos
            datasize = buffersize(buf)
        else
            datapos = buf.markpos
            datasize = buffersize(buf) + buf.bufferpos - buf.markpos
        end
        copy!(buf.data, 1, buf.data, datapos, datasize)
        buf.bufferpos -= datapos - 1
        buf.marginpos = buf.bufferpos + datasize
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

function skipbuffer!(buf::Buffer, n::Integer)
    if n > buffersize(buf)
        throw(ArgumentError("too large skip size"))
    end
    buf.bufferpos += n
    return buf
end

# Discard buffered data and initialize positions.
function initbuffer!(buf::Buffer)
    buf.markpos = 0
    buf.bufferpos = buf.marginpos = 1
    return buf
end

# Read as much data as possbile from `input` to the margin of `output`.
# This function will not block if `input` has buffered data.
function readdata!(input::IO, output::Buffer)
    nread::Int = 0
    navail = nb_available(input)
    if navail == 0 && marginsize(output) > 0 && !eof(input)
        nread += writebyte!(output, read(input, UInt8))
        navail = nb_available(input)
    end
    n = min(navail, marginsize(output))
    Base.unsafe_read(input, marginptr(output), n)
    output.marginpos += n
    nread += n
    return nread
end

# Read data from `buf` to `dst`.
function readdata!(buf::Buffer, dst::Vector{UInt8}, dpos::Integer, sz::Integer)
    copy!(dst, dpos, buf.data, buf.bufferpos, sz)
    buf.bufferpos += sz
    return dst
end

# Write all data to `output` from the buffer of `input`.
function writebuffer!(output::IO, input::Buffer)
    while buffersize(input) > 0
        input.bufferpos += Base.unsafe_write(output, bufferptr(input), buffersize(input))
    end
end

# Find the first occurrence of a specific byte.
function findbyte(buf::Buffer, byte::UInt8)
    ptr = ccall(:memchr, Ptr{Void}, (Ptr{Void}, Cint, Csize_t), pointer(buf.data, buf.bufferpos), byte, buffersize(buf))
    if ptr == C_NULL
        return 0
    else
        return Int(ptr - pointer(buf.data, buf.bufferpos)) + buf.bufferpos
    end
end
