
<a id='Reference-1'></a>

# Reference




<a id='TranscodingStream-1'></a>

## TranscodingStream

<a id='TranscodingStreams.TranscodingStream-Tuple{TranscodingStreams.Codec,IO}' href='#TranscodingStreams.TranscodingStream-Tuple{TranscodingStreams.Codec,IO}'>#</a>
**`TranscodingStreams.TranscodingStream`** &mdash; *Method*.



```
TranscodingStream(codec::Codec, stream::IO;
                  bufsize::Integer=16384,
                  stop_on_end::Bool=false,
                  sharedbuf::Bool=(stream isa TranscodingStream))
```

Create a transcoding stream with `codec` and `stream`.

A `TranscodingStream` object wraps an input/output stream object `stream`, and transcodes the byte stream using `codec`. It is a subtype of `IO` and supports most of the I/O functions in the standard library.

See the docs ([https://bicycle1885.github.io/TranscodingStreams.jl/stable/](https://bicycle1885.github.io/TranscodingStreams.jl/stable/)) for available codecs, examples, and more details of the type.

**Arguments**

  * `codec`:   The data transcoder. The transcoding stream does the initialization and   finalization of `codec`. Therefore, a codec object is not reusable once it   is passed to a transcoding stream.
  * `stream`:   The wrapped stream. It must be opened before passed to the constructor.
  * `bufsize`:   The initial buffer size (the default size is 16KiB). The buffer may be   extended whenever `codec` requests so.
  * `stop_on_end`:   The flag to stop transcoding on `:end` return code from `codec`.  The   transcoded data are readable even after stopping transcoding process.  With   this flag on, `stream` is not closed when the wrapper stream is closed with   `close`.  Note that some extra data may be read from `stream` into an   internal buffer, and thus `stream` must be a `TranscodingStream` object and   `sharedbuf` must be `true` to reuse `stream`.
  * `sharedbuf`:   The flag to share buffers between adjacent transcoding streams.  The value   must be `false` if `stream` is not a `TranscodingStream` object.

**Examples**

```julia
julia> using TranscodingStreams

julia> using CodecZlib

julia> file = open(Pkg.dir("TranscodingStreams", "test", "abra.gzip"));

julia> stream = TranscodingStream(GzipDecompressor(), file)
TranscodingStreams.TranscodingStream{CodecZlib.GzipDecompressor,IOStream}(<mode=idle>)

julia> readstring(stream)
"abracadabra"

```


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L56-L111' class='documenter-source'>source</a><br>

<a id='Base.transcode-Tuple{Type{#s1} where #s1<:TranscodingStreams.Codec,Union{Array{UInt8,1}, Base.CodeUnits{UInt8,S} where S<:AbstractString}}' href='#Base.transcode-Tuple{Type{#s1} where #s1<:TranscodingStreams.Codec,Union{Array{UInt8,1}, Base.CodeUnits{UInt8,S} where S<:AbstractString}}'>#</a>
**`Base.transcode`** &mdash; *Method*.



```
transcode(::Type{C}, data::Vector{UInt8})::Vector{UInt8} where C<:Codec
```

Transcode `data` by applying a codec `C()`.

Note that this method does allocation and deallocation of `C()` in every call, which is handy but less efficient when transcoding a number of objects. `transcode(codec, data)` is a recommended method in terms of performance.

**Examples**

```julia
julia> using CodecZlib

julia> data = b"abracadabra";

julia> compressed = transcode(ZlibCompressor, data);

julia> decompressed = transcode(ZlibDecompressor, compressed);

julia> String(decompressed)
"abracadabra"

```


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/transcode.jl#L4-L29' class='documenter-source'>source</a><br>

<a id='Base.transcode-Tuple{TranscodingStreams.Codec,Union{Array{UInt8,1}, Base.CodeUnits{UInt8,S} where S<:AbstractString}}' href='#Base.transcode-Tuple{TranscodingStreams.Codec,Union{Array{UInt8,1}, Base.CodeUnits{UInt8,S} where S<:AbstractString}}'>#</a>
**`Base.transcode`** &mdash; *Method*.



```
transcode(codec::Codec, data::Vector{UInt8})::Vector{UInt8}
```

Transcode `data` by applying `codec`.

Note that this method does not initialize or finalize `codec`. This is efficient when you transcode a number of pieces of data, but you need to call [`TranscodingStreams.initialize`](reference.md#TranscodingStreams.initialize) and [`TranscodingStreams.finalize`](reference.md#TranscodingStreams.finalize) explicitly.

**Examples**

```julia
julia> using CodecZlib

julia> data = b"abracadabra";

julia> codec = ZlibCompressor();

julia> TranscodingStreams.initialize(codec)

julia> compressed = transcode(codec, data);

julia> TranscodingStreams.finalize(codec)

julia> codec = ZlibDecompressor();

julia> TranscodingStreams.initialize(codec)

julia> decompressed = transcode(codec, compressed);

julia> TranscodingStreams.finalize(codec)

julia> String(decompressed)
"abracadabra"

```


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/transcode.jl#L40-L78' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.TOKEN_END' href='#TranscodingStreams.TOKEN_END'>#</a>
**`TranscodingStreams.TOKEN_END`** &mdash; *Constant*.



A special token indicating the end of data.

`TOKEN_END` may be written to a transcoding stream like `write(stream, TOKEN_END)`, which will terminate the current transcoding block.

!!! note
    Call `flush(stream)` after `write(stream, TOKEN_END)` to make sure that all data are written to the underlying stream.



<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L484-L494' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.unsafe_read' href='#TranscodingStreams.unsafe_read'>#</a>
**`TranscodingStreams.unsafe_read`** &mdash; *Function*.



```
unsafe_read(input::IO, output::Ptr{UInt8}, nbytes::Int)::Int
```

Copy at most `nbytes` from `input` into `output`.

This function is similar to `Base.unsafe_read` but is different in some points:

  * It does not throw `EOFError` when it fails to read `nbytes` from `input`.
  * It returns the number of bytes written to `output`.
  * It does not block if there are buffered data in `input`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/io.jl#L4-L13' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.unread' href='#TranscodingStreams.unread'>#</a>
**`TranscodingStreams.unread`** &mdash; *Function*.



```
unread(stream::TranscodingStream, data::Vector{UInt8})
```

Insert `data` to the current reading position of `stream`.

The next `read(stream, sizeof(data))` call will read data that are just inserted.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L411-L418' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.unsafe_unread' href='#TranscodingStreams.unsafe_unread'>#</a>
**`TranscodingStreams.unsafe_unread`** &mdash; *Function*.



```
unsafe_unread(stream::TranscodingStream, data::Ptr, nbytes::Integer)
```

Insert `nbytes` pointed by `data` to the current reading position of `stream`.

The data are copied into the internal buffer and hence `data` can be safely used after the operation without interfering the stream.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L423-L430' class='documenter-source'>source</a><br>

<a id='Base.position-Tuple{TranscodingStream}' href='#Base.position-Tuple{TranscodingStream}'>#</a>
**`Base.position`** &mdash; *Method*.



```
position(stream::TranscodingStream)
```

Return the number of bytes read from or written to `stream`.

Note that the returned value will be different from that of the underlying stream wrapped by `stream`.  This is because `stream` buffers some data and the codec may change the length of data.

**Examples**

```
julia> using CodecZlib, TranscodingStreams

julia> file = open(joinpath(dirname(pathof(CodecZlib)), "..", "test", "abra.gz"));

julia> stream = GzipDecompressorStream(file)
TranscodingStream{GzipDecompressor,IOStream}(<mode=idle>)

julia> position(stream)
0

julia> read(stream, 4)
4-element Array{UInt8,1}:
 0x61
 0x62
 0x72
 0x61

julia> position(stream)
4
```


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L246-L279' class='documenter-source'>source</a><br>


<a id='Statistics-1'></a>

## Statistics

<a id='TranscodingStreams.Stats' href='#TranscodingStreams.Stats'>#</a>
**`TranscodingStreams.Stats`** &mdash; *Type*.



I/O statistics.

Its object has four fields:

  * `in`: the number of bytes supplied into the stream
  * `out`: the number of bytes consumed out of the stream
  * `transcoded_in`: the number of bytes transcoded from the input buffer
  * `transcoded_out`: the number of bytes transcoded to the output buffer

Note that, since the transcoding stream does buffering, `in` is `transcoded_in + {size of buffered data}` and `out` is `transcoded_out - {size of buffered data}`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L517-L529' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.stats' href='#TranscodingStreams.stats'>#</a>
**`TranscodingStreams.stats`** &mdash; *Function*.



```
stats(stream::TranscodingStream)
```

Create an I/O statistics object of `stream`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/stream.jl#L545-L549' class='documenter-source'>source</a><br>


<a id='Codec-1'></a>

## Codec

<a id='TranscodingStreams.Noop' href='#TranscodingStreams.Noop'>#</a>
**`TranscodingStreams.Noop`** &mdash; *Type*.



```
Noop()
```

Create a noop codec.

Noop (no operation) is a codec that does nothing. The data read from or written to the stream are kept as-is without any modification. This is often useful as a buffered stream or an identity element of a composition of streams.

The implementations are specialized for this codec. For example, a `Noop` stream uses only one buffer rather than a pair of buffers, which avoids copying data between two buffers and the throughput will be larger than a naive implementation.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/noop.jl#L4-L17' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.NoopStream' href='#TranscodingStreams.NoopStream'>#</a>
**`TranscodingStreams.NoopStream`** &mdash; *Type*.



```
NoopStream(stream::IO)
```

Create a noop stream.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/noop.jl#L22-L26' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.Codec' href='#TranscodingStreams.Codec'>#</a>
**`TranscodingStreams.Codec`** &mdash; *Type*.



An abstract codec type.

Any codec supporting the transcoding protocol must be a subtype of this type.

**Transcoding protocol**

Transcoding proceeds by calling some functions in a specific way. We call this "transcoding protocol" and any codec must implement it as described below.

There are six functions for a codec to implement:

  * `expectedsize`: return the expected size of transcoded data
  * `minoutsize`: return the minimum output size of `process`
  * `initialize`: initialize the codec
  * `finalize`: finalize the codec
  * `startproc`: start processing with the codec
  * `process`: process data with the codec.

These are defined in the `TranscodingStreams` and a new codec type must extend these methods if necessary.  Implementing a `process` method is mandatory but others are optional.  `expectedsize`, `minoutsize`, `initialize`, `finalize`, and `startproc` have a default implementation.

Your codec type is denoted by `C` and its object by `codec`.

Errors that occur in these methods are supposed to be unrecoverable and the stream will go to the panic mode. Only `Base.isopen` and `Base.close` are available in that mode.

**`expectedsize`**

The `expectedsize(codec::C, input::Memory)::Int` method takes `codec` and `input`, and returns the expected size of transcoded data. This method will be used as a hint to determine the size of a data buffer when `transcode` is called. A good hint will reduce the number of buffer resizing and hence result in better performance.

**`minoutsize`**

The `minoutsize(codec::C, input::Memory)::Int` method takes `codec` and `input`, and returns the minimum required size of the output memory when `process` is called.  For example, an encoder of base64 will write at least four bytes to the output and hence it is reasonable to return 4 with this method.

**`initialize`**

The `initialize(codec::C)::Void` method takes `codec` and returns `nothing`. This is called once and only once before starting any data processing. Therefore, you may initialize `codec` (e.g. allocating memory needed to process data) with this method. If initialization fails for some reason, it may throw an exception and no other methods (including `finalize`) will be called. Therefore, you need to release the memory before throwing an exception.

**`finalize`**

The `finalize(codec::C)::Void` method takes `codec` and returns `nothing`.  This is called once and only only once just before the transcoding stream goes to the close mode (i.e. when `Base.close` is called) or just after `startproc` or `process` throws an exception. Other errors that happen inside the stream (e.g. `EOFError`) will not call this method. Therefore, you may finalize `codec` (e.g. freeing memory) with this method. If finalization fails for some reason, it may throw an exception. You should release the allocated memory in codec before returning or throwing an exception in `finalize` because otherwise nobody cannot release the memory. Even when an exception is thrown while finalizing a stream, the stream will become the close mode for safety.

**`startproc`**

The `startproc(codec::C, mode::Symbol, error::Error)::Symbol` method takes `codec`, `mode` and `error`, and returns a status code. This is called just before the stream starts reading or writing data. `mode` is either `:read` or `:write` and then the stream starts reading or writing, respectively.  The return code must be `:ok` if `codec` is ready to read or write data.  Otherwise, it must be `:error` and the `error` argument must be set to an exception object.

**`process`**

The `process(codec::C, input::Memory, output::Memory, error::Error)::Tuple{Int,Int,Symbol}` method takes `codec`, `input`, `output` and `error`, and returns a consumed data size, a produced data size and a status code. This is called repeatedly while processing data. The input (`input`) and output (`output`) data are a `Memory` object, which is a pointer to a contiguous memory region with size. You must read input data from `input`, transcode the bytes, and then write the output data to `output`.  Finally you need to return the size of read data, the size of written data, and `:ok` status code so that the caller can know how many bytes are consumed and produced in the method. When transcoding reaches the end of a data stream, it is notified to this method by empty input. In that case, the method need to write the buffered data (if any) to `output`. If there is no data to write, the status code must be set to `:end`. The `process` method will be called repeatedly until it returns `:end` status code. If an error happens while processing data, the `error` argument must be set to an exception object and the return code must be `:error`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L4-L97' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.expectedsize' href='#TranscodingStreams.expectedsize'>#</a>
**`TranscodingStreams.expectedsize`** &mdash; *Function*.



```
expectedsize(codec::Codec, input::Memory)::Int
```

Return the expected size of the transcoded `input` with `codec`.

The default method returns `input.size`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L104-L110' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.minoutsize' href='#TranscodingStreams.minoutsize'>#</a>
**`TranscodingStreams.minoutsize`** &mdash; *Function*.



```
minoutsize(codec::Codec, input::Memory)::Int
```

Return the minimum output size to be ensured when calling `process`.

The default method returns `max(1, div(input.size, 4))`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L115-L121' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.initialize' href='#TranscodingStreams.initialize'>#</a>
**`TranscodingStreams.initialize`** &mdash; *Function*.



```
initialize(codec::Codec)::Void
```

Initialize `codec`.

The default method does nothing.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L126-L132' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.finalize' href='#TranscodingStreams.finalize'>#</a>
**`TranscodingStreams.finalize`** &mdash; *Function*.



```
finalize(codec::Codec)::Void
```

Finalize `codec`.

The default method does nothing.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L137-L143' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.startproc' href='#TranscodingStreams.startproc'>#</a>
**`TranscodingStreams.startproc`** &mdash; *Function*.



```
startproc(codec::Codec, mode::Symbol, error::Error)::Symbol
```

Start data processing with `codec` of `mode`.

The default method does nothing and returns `:ok`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L148-L154' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.process' href='#TranscodingStreams.process'>#</a>
**`TranscodingStreams.process`** &mdash; *Function*.



```
process(codec::Codec, input::Memory, output::Memory, error::Error)::Tuple{Int,Int,Symbol}
```

Do data processing with `codec`.

There is no default method.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/codec.jl#L159-L165' class='documenter-source'>source</a><br>


<a id='Internal-types-1'></a>

## Internal types

<a id='TranscodingStreams.Memory' href='#TranscodingStreams.Memory'>#</a>
**`TranscodingStreams.Memory`** &mdash; *Type*.



A contiguous memory.

This type works like a `Vector` method.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/memory.jl#L4-L8' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.Error' href='#TranscodingStreams.Error'>#</a>
**`TranscodingStreams.Error`** &mdash; *Type*.



Container of transcoding error.

An object of this type is used to notify the caller of an exception that happened inside a transcoding method.  The `error` field is undefined at first but will be filled when data processing failed. The error should be set by calling the `setindex!` method (e.g. `error[] = ErrorException("error!")`).


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/error.jl#L4-L11' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.State' href='#TranscodingStreams.State'>#</a>
**`TranscodingStreams.State`** &mdash; *Type*.



A mutable state type of transcoding streams.

See Developer's notes for details.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/blob/8649b8394cdd1fc877dac5e6654b79992a35d0c7/src/state.jl#L5-L9' class='documenter-source'>source</a><br>

