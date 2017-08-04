# Codec Interfaces
# ================

"""
An abstract codec type.

Any codec supporting the transcoding protocol must be a subtype of this type.


Transcoding protocol
--------------------

Transcoding proceeds by calling some functions in a specific way. We call this
"transcoding protocol" and any codec must implement it as described below.

There are four functions for a codec to implement:
- initialize: initialize the codec
- finalize: finalize the codec
- startproc: start processing with the codec
- process: process data with the codec.

These are defined in the `TranscodingStreams` and a new codec type must extend
these methods if necessary.  Implementing a `process` method is mandatory but
other three are optional.  `initialize`, `finalize`, and `startproc` have a
default implementation that does nothing.

Your codec type is denoted by `C` and its object by `codec`.

The `initialize(codec::C)::Void` method takes `codec` and returns
`nothing`. This is called once and only once before starting any data
processing.  Therefore, you may initialize `codec` (e.g. allocating memory
needed to process data) with this method. If initialization fails for some
reason, it may throw an exception and no other methods will be called.

The `finalize(codec::C)::Void` method takes `codec` and returns `nothing`.  This
is called when and only when the transcoding stream goes to the close state
(i.e. when `Base.close` is called). Therefore, you may finalize `codec` (e.g.
freeing memory) with this method. If finalization fails for some reason, it may
throw an exception. Even when an exception is thrown while finalizing a stream,
the stream will become the close state for safety.

The `startproc(codec::C, state::Symbol)::Symbol` method takes `codec` and
`state`, and returns a status code. This is called just before the stream starts
reading or writing data. `state` is either `:read` or `:write` and then the
stream starts reading or writing, respectively. The return code must be `:ok` if
`codec` is ready to read or write data. Otherwise, it should be `:fail` and then
the stream throws an exception.

The `process(codec::C, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}`
method takes `codec`, `input` and `output`, and returns a consumed data size, a
produced data size and a status code. This is called repeatedly while processing
data. The input (`input`) and output (`output`) data are a `Memory` object,
which is a pointer to a contiguous memory region with size. You must read input
data from `input`, transcode the bytes, and then write the output data to
`output`.  Finally you need to return the size of read data, the size of written
data, and `:ok` status code so that the caller can know how many bytes are
consumed and produced in the method.  When transcoding reaches the end of a data
stream, it is notified to this method by empty input. In that case, the method
need to write the buffered data (if any) to `output`. If there is no data to
write, the status code must be set to `:end`. The `process` method will be
called repeatedly until it returns `:end` status code.

"""
abstract type Codec end


# Methods
# -------

"""
    initialize(codec::Codec)::Void

Initialize `codec`.
"""
function initialize(codec::Codec)
    return nothing
end

"""
    finalize(codec::Codec)::Void

Finalize `codec`.
"""
function finalize(codec::Codec)::Void
    return nothing
end

"""
    startproc(codec::Codec, state::Symbol)::Symbol

Start data processing with `codec` of `state`.
"""
function startproc(codec::Codec, state::Symbol)::Symbol
    return :ok
end

"""
    process(codec::Codec, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}

Do data processing with `codec`.
"""
function process(codec::Codec, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}
    # no default method
    throw(MethodError(process, (codec, input, output)))
end
