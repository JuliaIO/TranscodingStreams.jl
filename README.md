TranscodingStreams.jl
=====================

<!--[![Appveyor Status][appveyor-img]][appveyor-url]-->
[![Docs Stable][docs-stable-img]][docs-stable-url]
[![Docs Latest][docs-latest-img]][docs-latest-url]
[![TravisCI Status][travisci-img]][travisci-url]
[![codecov.io][codecov-img]][codecov-url]

![TranscodingStream](/docs/src/assets/transcodingstream.png)

TranscodingStreams.jl is a package for transcoding data streams. There are two
kinds of APIs:
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
stream = TranscodingStream(GzipCompression(), stream)
stream = TranscodingStream(GzipDecompression(), stream)
for line in eachline(stream)
    println(line)
end
close(stream)

# Array API.
array = Vector{UInt8}(text)
array = transcode(GzipCompression(), array)
array = transcode(GzipDecompression(), array)
@assert text == String(array)
```

Each codec has an alias for its transcoding stream type. For example,
`GzipCompressionStream{S} = TranscodingStream{GzipCompression,S} where S<:IO`.

The following packages support the interfaces of TranscodingStreams.jl:
- [CodecZlib.jl](https://github.com/bicycle1885/CodecZlib.jl)
- [CodecBzip2.jl](https://github.com/bicycle1885/CodecBzip2.jl)
- [CodecXz.jl](https://github.com/bicycle1885/CodecXz.jl)
- [CodecZstd.jl](https://github.com/bicycle1885/CodecZstd.jl)
- [CodecBase.jl](https://github.com/bicycle1885/CodecBase.jl)

Consult the [docs][docs-latest-url] for more details and examples.

[travisci-img]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl.svg?branch=master
[travisci-url]: https://travis-ci.org/bicycle1885/TranscodingStreams.jl
[codecov-img]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl/coverage.svg?branch=master
[codecov-url]: http://codecov.io/github/bicycle1885/TranscodingStreams.jl?branch=master
[docs-stable-img]: https://img.shields.io/badge/docs-stable-blue.svg
[docs-stable-url]: https://bicycle1885.github.io/TranscodingStreams.jl/stable/
[docs-latest-img]: https://img.shields.io/badge/docs-latest-blue.svg
[docs-latest-url]: https://bicycle1885.github.io/TranscodingStreams.jl/latest/
