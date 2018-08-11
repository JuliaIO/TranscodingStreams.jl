Examples
========

Read lines from a gzip-compressed file
--------------------------------------

The following snippet is an example of using CodecZlib.jl, which exports
`GzipDecompressorStream{S}` as an alias of
`TranscodingStream{GzipDecompressor,S}`, where `S` is a subtype of `IO`:
```julia
using CodecZlib
stream = GzipDecompressorStream(open("data.txt.gz"))
for line in eachline(stream)
    # do something...
end
close(stream)
```

Note that the last `close` call closes the wrapped file as well.
Alternatively, `open(<stream type>, <filepath>) do ... end` syntax closes the
file at the end:
```julia
using CodecZlib
open(GzipDecompressorStream, "data.txt.gz") do stream
    for line in eachline(stream)
        # do something...
    end
end
```

Read compressed data from a pipe
--------------------------------

The input is not limited to usual files. You can read data from a pipe
(actually, any `IO` object that implements standard I/O methods) as follows:
```julia
using CodecZlib
proc = open(`cat some.data.gz`)
stream = GzipDecompressorStream(proc)
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
using DelimitedFiles
mat = randn(100, 100)
stream = ZstdCompressorStream(open("data.mat.zst", "w"))
writedlm(stream, mat)
close(stream)
```

Of course, `open(<stream type>, ...) do ... end` just works:
```julia
using CodecZstd
using DelimitedFiles
mat = randn(100, 100)
open(ZstdCompressorStream, "data.mat.zst", "w") do stream
    writedlm(stream, mat)
end
```

Explicitly finish transcoding by writing `TOKEN_END`
----------------------------------------------------

When writing data, the end of a data stream is indicated by calling `close`,
which writes an epilogue if necessary and flushes all buffered data to the
underlying I/O stream. If you want to explicitly specify the end of a data
chunk for some reason, you can write `TranscodingStreams.TOKEN_END` to the
transcoding stream, which finishes the current transcoding process without
closing the underlying stream:
```julia
using CodecZstd
using TranscodingStreams
buf = IOBuffer()
stream = ZstdCompressorStream(buf)
write(stream, "foobarbaz"^100, TranscodingStreams.TOKEN_END)
flush(stream)
compressed = take!(buf)
close(stream)
```

Use a noop codec
----------------

The `Noop` codec does nothing (i.e., buffering data without transformation).
`NoopStream` is an alias of `TranscodingStream{Noop}`.  The following example
creates a decompressor stream based on the extension of a filepath:
```julia
using CodecZlib
using CodecXz
using TranscodingStreams

function makestream(filepath)
    if endswith(filepath, ".gz")
        codec = GzipDecompressor()
    elseif endswith(filepath, ".xz")
        codec = XzDecompressor()
    else
        codec = Noop()
    end
    return TranscodingStream(codec, open(filepath))
end

makestream("data.txt.gz")
makestream("data.txt.xz")
makestream("data.txt")
```

Change the codec of a file
--------------------------

`TranscodingStream`s are composable: a stream can be an input/output of another
stream. You can use this to change the format of a file by composing different
codecs as below:
```julia
using CodecZlib
using CodecZstd

input  = open("data.txt.gz",  "r")
output = open("data.txt.zst", "w")

stream = GzipDecompressorStream(ZstdCompressorStream(output))
write(stream, input)
close(stream)
```

Effectively, this is equivalent to the following pipeline:

    cat data.txt.gz | gzip -d | zstd >data.txt.zst

Stop decoding on the end of a block
-----------------------------------

Many codecs support decoding concatenated data blocks (or chunks). For example,
if you concatenate two gzip files into a single file and read it using
`GzipDecompressorStream`, you will see the byte stream of concatenation of the
two files. If you need the part corresponding the first file, you can set
`stop_on_end` to `true` to stop transcoding at the end of the first block.
Note that setting `stop_on_end` to `true` does not close the wrapped stream
because you will often want to reuse it.
```julia
using CodecZlib
# cat foo.txt.gz bar.txt.gz > foobar.txt.gz
stream = GzipDecompressorStream(open("foobar.txt.gz"), stop_on_end=true)
read(stream)  #> the content of foo.txt
eof(stream)   #> true
```

In the case where you need to reuse the wrapped stream, the code above must be
slightly modified because the transcoding stream may read more bytes than
necessary from the wrapped stream. Wrapping the stream with `NoopStream` solves
the problem because adjacent transcoding streams share the same buffer.
```julia
using CodecZlib
using TranscodingStreams
stream = NoopStream(open("foobar.txt.gz"))
read(GzipDecompressorStream(stream, stop_on_end=true))  #> the content of foo.txt
read(GzipDecompressorStream(stream, stop_on_end=true))  #> the content of bar.txt
```

Check I/O statistics
--------------------

`TranscodingStreams.stats` returns a snapshot of the I/O statistics. For
example, the following function shows progress of decompression to the standard
error:
```julia
using CodecZlib

function decompress(input, output)
    buffer = Vector{UInt8}(undef, 16 * 1024)
    while !eof(input)
        n = min(bytesavailable(input), length(buffer))
        unsafe_read(input, pointer(buffer), n)
        unsafe_write(output, pointer(buffer), n)
        stats = TranscodingStreams.stats(input)
        print(STDERR, "\rin: $(stats.in), out: $(stats.out)")
    end
    println(STDERR)
end

input = GzipDecompressorStream(open("foobar.txt.gz"))
output = IOBuffer()
decompress(input, output)
```

`stats.in` is the number of bytes supplied to the stream and `stats.out` is the
number of bytes consumed out of the stream.

Transcode data in one shot
--------------------------

TranscodingStreams.jl extends the `transcode` function to transcode a data
in one shot. `transcode` takes a codec object as its first argument and a data
vector as its second argument:
```julia
using CodecZlib
decompressed = transcode(ZlibDecompressor, b"x\x9cKL*JLNLI\x04R\x00\x19\xf2\x04U")
String(decompressed)
```

Transcode lots of strings
-------------------------

`transcode(<codec type>, data)` method is convenient but suboptimal when
transcoding a number of objects. This is because the method reallocates a new
codec object for every call. Instead, you can use `transcode(<codec object>,
data)` method that reuses the allocated object as follows. In this usage, you
need to explicitly allocate and free resources by calling
`TranscodingStreams.initialize` and `TranscodingStreams.finalize`,
respectively.

```julia
using CodecZstd
using TranscodingStreams
strings = ["foo", "bar", "baz"]
codec = ZstdCompressor()
TranscodingStreams.initialize(codec)  # allocate resources
try
    for s in strings
        data = transcode(codec, s)
        # do something...
    end
catch
    rethrow()
finally
    TranscodingStreams.finalize(codec)  # free resources
end
```

Unread data
-----------

`TranscodingStream` supports *unread* operation, which inserts data into the
current reading position. This is useful when you want to peek from the stream.
`TranscodingStreams.unread` and `TranscodingStreams.unsafe_unread` functions are
provided:
```julia
using TranscodingStreams
stream = NoopStream(open("data.txt"))
data1 = read(stream, 8)
TranscodingStreams.unread(stream, data1)
data2 = read(stream, 8)
@assert data1 == data2
```

The unread operation is different from the write operation in that the unreaded
data are not written to the wrapped stream. The unreaded data are stored in the
internal buffer of a transcoding stream.

Unfortunately, *unwrite* operation is not provided because there is no way to
cancel write operations that are already committed to the wrapped stream.
