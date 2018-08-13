TranscodingStreams.jl
=====================

<!--[![Appveyor Status][appveyor-img]][appveyor-url]-->
[![Docs Stable][docs-stable-img]][docs-stable-url]
[![Docs Latest][docs-latest-img]][docs-latest-url]
[![TravisCI Status][travisci-img]][travisci-url]
[![codecov.io][codecov-img]][codecov-url]

![TranscodingStream](/docs/src/assets/transcodingstream.png)

TranscodingStreams.jl is a package for transcoding data streams, which is:
- **fast**: small overhead and specialized methods,
- **consistent**: basic I/O operations you already know will work as you expect,
- **generic**: support any I/O objects like files, buffers, pipes, etc., and
- **extensible**: you can define a new codec to transcode data.

## Installation

```julia
Pkg.add("TranscodingStreams")
```

Installing a [codec package](#codec-packages) will install
TranscodingStreams.jl as well, and so in general you don't need to explicitly
install it.

## Usage

```julia
using TranscodingStreams, CodecZlib

# Some text.
text = """
Lorem ipsum dolor sit amet, consectetur adipiscing elit. Aenean sollicitudin
mauris non nisi consectetur, a dapibus urna pretium. Vestibulum non posuere
erat. Donec luctus a turpis eget aliquet. Cras tristique iaculis ex, eu
malesuada sem interdum sed. Vestibulum ante ipsum primis in faucibus orci luctus
et ultrices posuere cubilia Curae; Etiam volutpat, risus nec gravida ultricies,
erat ex bibendum ipsum, sed varius ipsum ipsum vitae dui.
"""

# Streaming API.
stream = IOBuffer(text)
stream = TranscodingStream(GzipCompressor(), stream)
stream = TranscodingStream(GzipDecompressor(), stream)
for line in eachline(stream)
    println(line)
end
close(stream)

# Array API.
array = Vector{UInt8}(text)
array = transcode(GzipCompressor, array)
array = transcode(GzipDecompressor, array)
@assert text == String(array)
```

Each codec has an alias to its transcoding stream type for ease of use. For
example, `GzipCompressorStream{S} = TranscodingStream{GzipCompressor,S} where
S<:IO`.

Consult the [docs][docs-latest-url] for more details and examples.

## Codec packages

TranscodingStreams.jl offers I/O interfaces to users. It also offers a protocol
suite to communicate with various codecs. However, specific codecs are not
included in this package except the `Noop` codec, which does nothing to data.
The user need to install codecs as a plug-in to do something meaningful.

The following codec packages support the protocol suite:
- [CodecZlib.jl](https://github.com/bicycle1885/CodecZlib.jl)
- [CodecXz.jl](https://github.com/bicycle1885/CodecXz.jl)
- [CodecZstd.jl](https://github.com/bicycle1885/CodecZstd.jl)
- [CodecBase.jl](https://github.com/bicycle1885/CodecBase.jl)
- [CodecBzip2.jl](https://github.com/bicycle1885/CodecBzip2.jl)
- [CodecLz4.jl](https://github.com/invenia/CodecLz4.jl) by Invenia.

[travisci-img]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl.svg?branch=master
[travisci-url]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl
[codecov-img]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl?branch=master
[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://bicycle1885.github.io/TranscodingStreams.jl/stable/
[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://bicycle1885.github.io/TranscodingStreams.jl/latest/
