Examples
========

Read lines from a gzip-compressed file
--------------------------------------

The following snippet is an example of using CodecZlib.jl, which exports
`GzipDecompressionStream{S}` as an alias of
`TranscodingStream{GzipDecompression,S} where S<:IO`:
```julia
using CodecZlib
stream = GzipDecompressionStream(open("data.txt.gz"))
for line in eachline(stream)
    # do something...
end
close(stream)
```

Note that the last `close` call will close the file as well.  Alternatively,
`open(<stream type>, <filepath>) do ... end` syntax will close the file at the
end:
```julia
using CodecZlib
open(GzipDecompressionStream, "data.txt.gz") do stream
    for line in eachline(stream)
        # do something...
    end
end
```

Read compressed data from a pipe
--------------------------------

The input is not limited to usual files. You can read data from a pipe
(actually, any `IO` object that implements basic I/O methods) as follows:
```julia
using CodecZlib
pipe, proc = open(`cat some.data.gz`)
stream = GzipDecompressionStream(pipe)
for line in eachline(stream)
    # do something...
end
close(stream)  # This will finish the process as well.
```

Save a data matrix with Zstd compression
----------------------------------------

Writing compressed data is easy. One thing you need to keep in mind is to call
`close` after writing data; otherwise, the output file will be incomplete:
```julia
using CodecZstd
mat = randn(100, 100)
stream = ZstdCompressionStream(open("data.mat.zst", "w"))
writedlm(stream, mat)
close(stream)
```

Of course, `open(<stream type>, ...) do ... end` works well:
```julia
using CodecZstd
mat = randn(100, 100)
open(ZstdCompressionStream, "data.mat.zst", "w") do stream
    writedlm(stream, mat)
end
```

Explicitly finish transcoding by writing `TOKEN_END`
----------------------------------------------------

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

Use a noop codec
----------------

Sometimes, the `Noop` codec, which does nothing, may be useful. The following
example creates a decompression stream based on the extension of a filepath:
```julia
using CodecZlib
using CodecBzip2
using TranscodingStreams

function makestream(filepath)
    if endswith(filepath, ".gz")
        codec = GzipDecompression()
    elseif endswith(filepath, ".bz2")
        codec = Bzip2Decompression()
    else
        codec = Noop()
    end
    return TranscodingStream(codec, open(filepath))
end

makestream("data.txt.gz")
makestream("data.txt.bz2")
makestream("data.txt")
```

Transcode data in one shot
--------------------------

TranscodingStreams.jl extends the `transcode` function to transcode a data
in one shot. `transcode` takes a codec object as its first argument and a data
vector as its second argument:
```julia
using CodecZlib
decompressed = transcode(ZlibDecompression(), b"x\x9cKL*JLNLI\x04R\x00\x19\xf2\x04U")
String(decompressed)
```
