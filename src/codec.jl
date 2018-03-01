# Codec Interfaces
# ================

"""
An abstract codec type.

Any codec supporting the transcoding protocol must be a subtype of this type.

Transcoding protocol
--------------------

Transcoding proceeds by calling some functions in a specific way. We call this
"transcoding protocol" and any codec must implement it as described below.

There are six functions for a codec to implement:
- `expectedsize`: return the expected size of transcoded data
- `minoutsize`: return the minimum output size of `process`
- `initialize`: initialize the codec
- `finalize`: finalize the codec
- `startproc`: start processing with the codec
- `process`: process data with the codec.

These are defined in the `TranscodingStreams` and a new codec type must extend
these methods if necessary.  Implementing a `process` method is mandatory but
others are optional.  `expectedsize`, `minoutsize`, `initialize`, `finalize`,
and `startproc` have a default implementation.

Your codec type is denoted by `C` and its object by `codec`.

Errors that occur in these methods are supposed to be unrecoverable and the
stream will go to the panic mode. Only `Base.isopen` and `Base.close` are
available in that mode.

### `expectedsize`

The `expectedsize(codec::C, input::Memory)::Int` method takes `codec` and
`input`, and returns the expected size of transcoded data. This method will be
used as a hint to determine the size of a data buffer when `transcode` is
called. A good hint will reduce the number of buffer resizing and hence result
in better performance.

### `minoutsize`

The `minoutsize(codec::C, input::Memory)::Int` method takes `codec` and `input`,
and returns the minimum required size of the output memory when `process` is
called.  For example, an encoder of base64 will write at least four bytes to the
output and hence it is reasonable to return 4 with this method.

### `initialize`

The `initialize(codec::C)::Void` method takes `codec` and returns `nothing`.
This is called once and only once before starting any data processing.
Therefore, you may initialize `codec` (e.g. allocating memory needed to process
data) with this method. If initialization fails for some reason, it may throw an
exception and no other methods (including `finalize`) will be called. Therefore,
you need to release the memory before throwing an exception.

### `finalize`

The `finalize(codec::C)::Void` method takes `codec` and returns `nothing`.  This
is called once and only only once just before the transcoding stream goes to the
close mode (i.e. when `Base.close` is called) or just after `startproc` or
`process` throws an exception. Other errors that happen inside the stream (e.g.
`EOFError`) will not call this method. Therefore, you may finalize `codec` (e.g.
freeing memory) with this method. If finalization fails for some reason, it may
throw an exception. You should release the allocated memory in codec before
returning or throwing an exception in `finalize` because otherwise nobody cannot
release the memory. Even when an exception is thrown while finalizing a stream,
the stream will become the close mode for safety.

### `startproc`

The `startproc(codec::C, mode::Symbol, error::Error)::Symbol` method takes
`codec`, `mode` and `error`, and returns a status code. This is called just
before the stream starts reading or writing data. `mode` is either `:read` or
`:write` and then the stream starts reading or writing, respectively.  The
return code must be `:ok` if `codec` is ready to read or write data.  Otherwise,
it must be `:error` and the `error` argument must be set to an exception object.

### `process`

The `process(codec::C, input::Memory, output::Memory,
error::Error)::Tuple{Int,Int,Symbol}` method takes `codec`, `input`, `output`
and `error`, and returns a consumed data size, a produced data size and a status
code. This is called repeatedly while processing data. The input (`input`) and
output (`output`) data are a `Memory` object, which is a pointer to a contiguous
memory region with size. You must read input data from `input`, transcode the
bytes, and then write the output data to `output`.  Finally you need to return
the size of read data, the size of written data, and `:ok` status code so that
the caller can know how many bytes are consumed and produced in the method.
When transcoding reaches the end of a data stream, it is notified to this method
by empty input. In that case, the method need to write the buffered data (if
any) to `output`. If there is no data to write, the status code must be set to
`:end`. The `process` method will be called repeatedly until it returns `:end`
status code. If an error happens while processing data, the `error` argument
must be set to an exception object and the return code must be `:error`.
"""
abstract type Codec end


# Methods
# -------

"""
    expectedsize(codec::Codec, input::Memory)::Int

Return the expected size of the transcoded `input` with `codec`.

The default method returns `input.size`.
"""
function expectedsize(codec::Codec, input::Memory)::Int
    return input.size
end

"""
    minoutsize(codec::Codec, input::Memory)::Int

Return the minimum output size to be ensured when calling `process`.

The default method returns `max(1, div(input.size, 4))`.
"""
function minoutsize(codec::Codec, input::Memory)::Int
    return max(1, div(input.size, 4))
end

"""
    initialize(codec::Codec)::Void

Initialize `codec`.

The default method does nothing.
"""
function initialize(codec::Codec)
    return nothing
end

"""
    finalize(codec::Codec)::Void

Finalize `codec`.

The default method does nothing.
"""
function finalize(codec::Codec)::Nothing
    return nothing
end

"""
    startproc(codec::Codec, mode::Symbol, error::Error)::Symbol

Start data processing with `codec` of `mode`.

The default method does nothing and returns `:ok`.
"""
function startproc(codec::Codec, mode::Symbol, error::Error)::Symbol
    return :ok
end

"""
    process(codec::Codec, input::Memory, output::Memory, error::Error)::Tuple{Int,Int,Symbol}

Do data processing with `codec`.

There is no default method.
"""
function process(codec::Codec, input::Memory, output::Memory, error::Error)::Tuple{Int,Int,Symbol}
    # no default method
    throw(MethodError(process, (codec, input, output, error)))
end
