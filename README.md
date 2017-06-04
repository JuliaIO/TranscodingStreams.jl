TranscodingStreams.jl - IO streams with transcoding
===================================================

<!--[![Docs Latest][docs-latest-img]][docs-latest-url]-->
[![TravisCI Status][travisci-img]][travisci-url]
<!--[![Appveyor Status][appveyor-img]][appveyor-url]-->
[![codecov.io][codecov-img]][codecov-url]

TranscodingStreams.jl exports a type `TranscodingStream{C<:Codec,S<:IO}<:IO`
which wraps `S<:IO` using `C<:Codec`. Codecs are defined in other packages
listed below:

- [CodecZlib.jl](https://github.com/bicycle1885/CodecZlib.jl)
    - `GzipCompression` (`GzipCompressionStream`)
    - `GzipDecompression` (`GzipDecompressionStream`)
    - `ZlibCompression` (`ZlibCompressionStream`)
    - `ZlibDecompression` (`ZlibDecompressionStream`)
    - `RawCompression` (`RawCompressionStream`)
    - `RawDecompression` (`RawDecompressionStream`)
- [CodecZstd.jl](https://github.com/bicycle1885/CodecZstd.jl)
    - `ZstdCompression` (`ZstdCompressionStream`)
    - `ZstdDecompression` (`ZstdDecompressionStream`)
- [CodecBzip2.jl](https://github.com/bicycle1885/CodecBzip2.jl)
    - `Bzip2Compression` (`Bzip2CompressionStream`)
    - `Bzip2Decompression` (`Bzip2DecompressionStream`)

By convention, codec types have a name that matches `.*(Co|Deco)mpression` and
I/O types have a codec name with `Stream` suffix.  The following snippet is an
example of using CodecZlib.jl, which exports `GzipDecompressionStream` as an
alias of `TranscodingStream{GzipDecompression,S}` where `S<:IO`:
```julia
# Read lines from a gzip-compressed file.
using CodecZlib
stream = GzipDecompressionStream(open("data.gzip"))
for line in eachline(stream)
    # do something...
end
close(stream)
```

When writing data, the end of a data stream is indicated by calling `close`,
which may write an epilogue if necessary and flush all buffered data to the
underlying I/O stream. If you want to explicitly specify the end position of a
stream for some reason, you can write `TranscodingStreams.TOKEN_END` to the
transcoding stream as follows:
```julia
# Compress a string using zstd.
using CodecZstd
using TranscodingStreams
buf = IOBuffer()
stream = ZstdCompressionStream(buf)
write(stream, "foobarbaz"^100, TranscodingStreams.TOKEN_END)
flush(stream)
compressed = take!(buf)
close(stream)
```

TranscodingStreams.jl extends the `transcode` function to transcode a data
in one shot. `transcode` takes a codec object as its first argument and a data
vector as its second argument:
```julia
using CodecZlib
decompressed = transcode(ZlibDecompression(), b"x\x9cKL*JLNLI\x04R\x00\x19\xf2\x04U")
String(decompressed)
```

[travisci-img]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl.svg?branch=master
[travisci-url]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl
[codecov-img]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl?branch=master
