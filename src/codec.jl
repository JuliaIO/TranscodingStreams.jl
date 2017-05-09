# Codec Interfaces
# ================

abstract type Codec end

abstract type Mode end
struct Read  <: Mode end
struct Write <: Mode end

primitive type ProcCode 8 end
const PROC_INIT   = reinterpret(ProcCode, 0x00)
const PROC_OK     = reinterpret(ProcCode, 0x01)
const PROC_FINISH = reinterpret(ProcCode, 0x02)


# Start
# -----

"""
    start(::Type{Read}, codec::Codec, source::IO)::Void

Start transcoding using `codec` with read mode.

This method will be called only once before calling `process` first time.

Implementing this method is optional; there is a default method that does nothing.
"""
function start(::Type{Read}, ::Codec, ::IO)
    return nothing
end

"""
    start(::Type{Write}, codec::Codec, sink::IO)::Void

Start transcoding using `codec` with write mode.

This method will be called only once before calling `process` first time.

Implementing this method is optional; there is a default method that does nothing.
"""
function start(::Type{Write}, ::Codec, ::IO)
    return nothing
end


# Process
# -------

"""
    process(::Type{Read}, codec::Codec, source::IO, output::Ptr{UInt8}, nbytes::Int)::Tuple{Int,ProcCode}

Transcode data using `codec` with read mode.

      <>    >-----(process)----->  [........]
    source          codec            output

This method reads some data from `source` and write the transcoded data to
`output` at most `nbytes`, and then returns the number of written bytes and an
appropriate return code.  It will be called repeatedly to incrementally
transcode input data from `source`. It can assume `output` points to a valid
memory position and `nbytes` are positive.  The intermediate result of
transcoding is indicated by the return value of it.  If processing works
properly and there are still data to write, it must return the number of written
bytes and `PROC_OK`.  If processing finishes and there are no remaining data to
write, it must return the number of written bytes and `PROC_FINISH`. Therefore,
after finishing reading data from `source` and all (possibly buffered) data are
written to `output`, it is expected to return `(0, PROC_FINISH)` forever.

This method may throw an exception when transcoding fails. For example, when
`codec` is a decompression algorithm, it may throw an exception if it reads
malfomed data from `source`.  However, this method must not throw `EOFError`
when reading data from `source`.  Also note that it is responsible for this
method to release resources allocated by `codec` when an exception happens.
"""
function process(::Type{Read}, codec::Codec, source::IO, input::Ptr{UInt8}, nbytes::Int)
    error("codec $(typeof(codec)) does not implement read mode")
end

"""
    process(::Type{Write}, codec::Codec, sink::IO, input::Ptr{UInt8}, nbytes::Int)::Tuple{Int,ProcCode}

Transcode data using `codec` with write mode.

      <>    <-----(transcode)-----<  [.......]
     sink            codec             input

This method reads some data from `input` and write the transcoded bytes to
`sink` at most `nbytes`, and then returns the number of written bytes and an
appropriate return code. It can assume `input` points to a valid memory position
and `nbytes` is positive.
"""
function process(::Type{Write}, codec::Codec, sink::IO, input::Ptr{UInt8}, nbytes::Int)
    error("codec $(typeof(codec)) does not implement write mode")
end


# Finish
# ------

"""
    finish(::Type{Read}, codec::Codec, source::IO)::Void

Finish transcoding using `codec` with read mode.

This method will be called only once after calling `process` last time.

Implementing this method is optional; there is a default method that does nothing.
"""
function finish(::Type{Read}, ::Codec, ::IO)
    return nothing
end

"""
    finish(::Type{Write}, codec::Codec, sink::IO)::Void

Finish transcoding using `codec` with write mode.

This method will be called only once after calling `process` last time.

Implementing this method is optional; there is a default method that does nothing.
"""
function finish(::Type{Write}, ::Codec, ::IO)
    return nothing
end
