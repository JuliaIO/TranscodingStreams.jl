TranscodingStreams.jl - IO streams with transcoding
===================================================

<!--[![Docs Latest][docs-latest-img]][docs-latest-url]-->
[![TravisCI Status][travisci-img]][travisci-url]
<!--[![Appveyor Status][appveyor-img]][appveyor-url]-->
[![codecov.io][codecov-img]][codecov-url]

TranscodingStreams.jl exports a type `TranscodingStream{C<:Codec,S<:IO}<:IO`
which wraps `S<:IO` using `C<:Codec`. Codecs are exported from other packages
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

The following snippet is an example of using CodecZlib.jl, which exports
`GzipDecompressionStream` as an alias of
`TranscodingStream{GzipDecompression,S}` where `S<:IO`:

```julia
# Read lines from a gzip-compressed file.
using CodecZlib
stream = GzipDecompressionStream(open("data.gzip"))
for line in eachline(stream)
    # do something...
end
close(stream)

# Compress a string using zstd.
using CodecZstd
using TranscodingStreams
buf = IOBuffer()
stream = ZstdCompressionStream(buf)
write(stream, "foobarbaz"^100, TranscodingStreams.TOKEN_END)
compressed = take!(buf)
close(stream)
```

[travisci-img]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl.svg?branch=master
[travisci-url]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl
[codecov-img]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl?branch=master
