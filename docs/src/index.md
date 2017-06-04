TranscodingStreams.jl
=====================

TranscodingStreams.jl is a package for transcoding (e.g. compression) data
streams. This package exports a type `TranscodingStream`, which
is a subtype of `IO` and supports various I/O operations like other usual I/O
streams in the standard library.


Introduction
------------

`TranscodingStream` has two type parameters, `C<:Codec` and `S<:IO`, and hence
the actual type should be written as `TranscodingStream{C<:Codec,S<:IO}`. This
type wraps an underlying I/O stream `S` by a codec `C`. The codec defines
transformation (or transcoding) of the stream. For example, when `C` is a
lossless decompression type and `S` is a file, `TranscodingStream{C,S}` behaves
like a data stream that incrementally decompresses data from the file.

Codecs are defined in other packages listed below:
- [CodecZlib.jl](https://github.com/bicycle1885/CodecZlib.jl)
    - `GizipCompression` (`GzipCompressionStream`)
    - `GzipDecompression` (`GzipDecompressionStream`)
    - `ZlibCompression` (`ZlibCompressionStream`)
    - `ZlibDecompression` (`ZlibDecompressionStream`)
    - `DeflateCompression` (`DeflateCompressionStream`)
    - `DeflateDecompression` (`DeflateDecompressionStream`)
- [CodecZngstd.jl](https://github.com/bicycle1885/CodecZstd.jl)
    - `ZstdCompression` (`ZstdCompressionStream`)
    - `ZstdDecompression` (`ZstdDecompressionStream`)
- [CodecBzip2.jl](https://github.com/bicycle1885/CodecBzip2.jl)
    - `Bzip2Compression` (`Bzip2CompressionStream`)
    - `Bzip2Decompression` (`Bzip2DecompressionStream`)

By convention, codec types have a name that matches `.*(Co|Deco)mpression` and
I/O types have a codec name with `Stream` suffix.  An important thing is these
packages depend on TranscodingStreams.jl and not *vice versa*. This means you
can install any codec package you need without installing all codec packages.
Also, if you want to define your own codec, it is totally feasible like these
packages.  TranscodingStreams.jl requests a codec to implement some interface
functions which will be described later.


Examples
--------

### Read lines from a gzip-compressed file

The following snippet is an example of using CodecZlib.jl, which exports
`GzipDecompressionStream{S}` as an alias of
`TranscodingStream{GzipDecompression,S} where S<:IO`:
```julia
using CodecZlib
stream = GzipDecompressionStream(open("data.gzip"))
for line in eachline(stream)
    # do something...
end
close(stream)
```

### Save a data matrix with Zstd compression

Writing compressed data is easy. One thing you need to keep in mind is to call
`close` after writing data; otherwise, the output file will be incomplete:
```julia
using CodecZstd
mat = randn(100, 100).^2
file = open("data.mat.zst", "w")
stream = ZstdCompressionStream(file)
writedlm(stream, mat)
close(stream)
```

### Explicitly finish transcoding by writing `TOKEN_END`

When writing data, the end of a data stream is indicated by calling `close`,
which may write an epilogue if necessary and flush all buffered data to the
underlying I/O stream. If you want to explicitly specify the end position of a
stream for some reason, you can write `TranscodingStreams.TOKEN_END` to the
transcoding stream as follows:
```julia
using CodecZstd
using TranscodingStreams
buf = IOBuffer()
stream = ZstdCompressionStream(buf)
write(stream, "foobarbaz"^100, TranscodingStreams.TOKEN_END)
flush(stream)
compressed = take!(buf)
close(stream)
```

### Transcode data in one shot

TranscodingStreams.jl extends the `transcode` function to transcode a data
in one shot. `transcode` takes a codec object as its first argument and a data
vector as its second argument:
```julia
using CodecZlib
decompressed = transcode(ZlibDecompression(), b"x\x9cKL*JLNLI\x04R\x00\x19\xf2\x04U")
String(decompressed)
```


API
---

```@meta
CurrentModule = TranscodingStreams
```

```@docs
TranscodingStream(codec::Codec, stream::IO)
transcode(codec::Codec, data::Vector{UInt8})
TranscodingStreams.TOKEN_END
```


Defining a new codec
--------------------

```@docs
TranscodingStreams.Codec
TranscodingStreams.initialize
TranscodingStreams.finalize
TranscodingStreams.startproc
TranscodingStreams.process
```
