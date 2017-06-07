
<a id='TranscodingStreams.jl-1'></a>

# TranscodingStreams.jl


TranscodingStreams.jl is a package for transcoding (e.g. compression) data streams. This package exports a type `TranscodingStream`, which is a subtype of `IO` and supports various I/O operations like other usual I/O streams in the standard library.


<a id='Introduction-1'></a>

## Introduction


`TranscodingStream` has two type parameters, `C<:Codec` and `S<:IO`, and hence the actual type should be written as `TranscodingStream{C<:Codec,S<:IO}`. This type wraps an underlying I/O stream `S` by a codec `C`. The codec defines transformation (or transcoding) of the stream. For example, when `C` is a lossless decompression type and `S` is a file, `TranscodingStream{C,S}` behaves like a data stream that incrementally decompresses data from the file.


Codecs are defined in other packages listed below:


<table>     <tr>         <th>Package</th>         <th>Library</th>         <th>Format</th>         <th>Codec</th>         <th>Stream</th>         <th>Description</th>     </tr>     <tr>         <td rowspan="6"><a href="https://github.com/bicycle1885/CodecZlib.jl">CodecZlib.jl</a></td>         <td rowspan="6"><a href="http://zlib.net/">zlib</a></td>         <td rowspan="2"><a href="https://tools.ietf.org/html/rfc1952">RFC1952</a></td>         <td><code>GzipCompression</code></td>         <td><code>GzipCompressionStream</code></td>         <td>Compress data in gzip (.gz) format.</td>     </tr>     <tr>         <td><code>GzipDecompression</code></td>         <td><code>GzipDecompressionStream</code></td>         <td>Decompress data in gzip (.gz) format.</td>     </tr>     <tr>         <td rowspan="2"><a href="https://tools.ietf.org/html/rfc1950">RFC1950</a></td>         <td><code>ZlibCompression</code></td>         <td><code>ZlibCompressionStream</code></td>         <td>Compress data in zlib format.</td>     </tr>     <tr>         <td><code>ZlibDecompression</code></td>         <td><code>ZlibDecompressionStream</code></td>         <td>Decompress data in zlib format.</td>     </tr>     <tr>         <td rowspan="2"><a href="https://tools.ietf.org/html/rfc1951">RFC1951</a></td>         <td><code>DeflateCompression</code></td>         <td><code>DeflateCompressionStream</code></td>         <td>Compress data in zlib format.</td>     </tr>     <tr>         <td><code>DeflateDecompression</code></td>         <td><code>DeflateDecompressionStream</code></td>         <td>Decompress data in zlib format.</td>     </tr>     <tr>         <td rowspan="2"><a href="https://github.com/bicycle1885/CodecBzip2.jl">CodecBzip2.jl</a></td>         <td rowspan="2"><a href="http://www.bzip.org/">bzip2</a></td>         <td rowspan="2"></td>         <td><code>Bzip2Compression</code></td>         <td><code>Bzip2CompressionStream</code></td>         <td>Compress data in bzip2 (.bz2) format.</td>     </tr>     <tr>         <td><code>Bzip2Decompression</code></td>         <td><code>Bzip2DecompressionStream</code></td>         <td>Decompress data in bzip2 (.bz2) format.</td>     </tr>     <tr>         <td rowspan="2"><a href="https://github.com/bicycle1885/CodecXz.jl">CodecXz.jl</a></td>         <td rowspan="2"><a href="https://tukaani.org/xz/">xz</a></td>         <td rowspan="2"><a href="https://tukaani.org/xz/xz-file-format.txt">The .xz File Format</a></td>         <td><code>XzCompression</code></td>         <td><code>XzCompressionStream</code></td>         <td>Compress data in xz (.xz) format.</td>     </tr>     <tr>         <td><code>XzDecompression</code></td>         <td><code>XzDecompressionStream</code></td>         <td>Decompress data in xz (.xz) format.</td>     </tr>     <tr>         <td rowspan="2"><a href="https://github.com/bicycle1885/CodecZstd.jl">CodecZstd.jl</a></td>         <td rowspan="2"><a href="http://facebook.github.io/zstd/">zstd</a></td>         <td rowspan="2"><a href="https://github.com/facebook/zstd/blob/dev/doc/zstd_compression_format.md">Zstandard Compression Format</a></td>         <td><code>ZstdCompression</code></td>         <td><code>ZstdCompressionStream</code></td>         <td>Compress data in zstd (.zst) format.</td>     </tr>     <tr>         <td><code>ZstdDecompression</code></td>         <td><code>ZstdDecompressionStream</code></td>         <td>Decompress data in zstd (.zst) format.</td>     </tr> </table>


By convention, codec types have a name that matches `.*(Co|Deco)mpression` and I/O types have a codec name with `Stream` suffix.  An important thing is these packages depend on TranscodingStreams.jl and not *vice versa*. This means you can install any codec package you need without installing all codec packages. Also, if you want to define your own codec, it is totally feasible like these packages.  TranscodingStreams.jl requests a codec to implement some interface functions which will be described later.


<a id='Examples-1'></a>

## Examples


<a id='Read-lines-from-a-gzip-compressed-file-1'></a>

### Read lines from a gzip-compressed file


The following snippet is an example of using CodecZlib.jl, which exports `GzipDecompressionStream{S}` as an alias of `TranscodingStream{GzipDecompression,S} where S<:IO`:


```julia
using CodecZlib
stream = GzipDecompressionStream(open("data.txt.gz"))
for line in eachline(stream)
    # do something...
end
close(stream)
```


Note that the last `close` call will close the file as well.  Alternatively, `open(<stream type>, <filepath>) do ... end` syntax will close the file at the end:


```julia
using CodecZlib
open(GzipDecompressionStream, "data.txt.gz") do stream
    for line in eachline(stream)
        # do something...
    end
end
```


<a id='Save-a-data-matrix-with-Zstd-compression-1'></a>

### Save a data matrix with Zstd compression


Writing compressed data is easy. One thing you need to keep in mind is to call `close` after writing data; otherwise, the output file will be incomplete:


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


<a id='Explicitly-finish-transcoding-by-writing-TOKEN_END-1'></a>

### Explicitly finish transcoding by writing `TOKEN_END`


When writing data, the end of a data stream is indicated by calling `close`, which may write an epilogue if necessary and flush all buffered data to the underlying I/O stream. If you want to explicitly specify the end position of a stream for some reason, you can write `TranscodingStreams.TOKEN_END` to the transcoding stream as follows:


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


<a id='Transcode-data-in-one-shot-1'></a>

### Transcode data in one shot


TranscodingStreams.jl extends the `transcode` function to transcode a data in one shot. `transcode` takes a codec object as its first argument and a data vector as its second argument:


```julia
using CodecZlib
decompressed = transcode(ZlibDecompression(), b"x\x9cKL*JLNLI\x04R\x00\x19\xf2\x04U")
String(decompressed)
```


<a id='API-1'></a>

## API



<a id='TranscodingStreams.TranscodingStream-Tuple{TranscodingStreams.Codec,IO}' href='#TranscodingStreams.TranscodingStream-Tuple{TranscodingStreams.Codec,IO}'>#</a>
**`TranscodingStreams.TranscodingStream`** &mdash; *Method*.



```
TranscodingStream(codec::Codec, stream::IO; bufsize::Integer=16384)
```

Create a transcoding stream with `codec` and `stream`.

**Examples**

```julia
julia> using TranscodingStreams

julia> using CodecZlib

julia> file = open(Pkg.dir("TranscodingStreams", "test", "abra.gzip"));

julia> stream = TranscodingStream(GzipDecompression(), file)
TranscodingStreams.TranscodingStream{CodecZlib.GzipDecompression,IOStream}(<state=idle>)

julia> readstring(stream)
"abracadabra"

```


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/stream.jl#L40-L62' class='documenter-source'>source</a><br>

<a id='Base.transcode-Tuple{TranscodingStreams.Codec,Array{UInt8,1}}' href='#Base.transcode-Tuple{TranscodingStreams.Codec,Array{UInt8,1}}'>#</a>
**`Base.transcode`** &mdash; *Method*.



```
transcode(codec::Codec, data::Vector{UInt8})::Vector{UInt8}
```

Transcode `data` by applying `codec`.

**Examples**

```julia
julia> using CodecZlib

julia> data = Vector{UInt8}("abracadabra");

julia> compressed = transcode(ZlibCompression(), data);

julia> decompressed = transcode(ZlibDecompression(), compressed);

julia> String(decompressed)
"abracadabra"

```


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/stream.jl#L306-L327' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.TOKEN_END' href='#TranscodingStreams.TOKEN_END'>#</a>
**`TranscodingStreams.TOKEN_END`** &mdash; *Constant*.



A special token indicating the end of data.

`TOKEN_END` may be written to a transcoding stream like `write(stream, TOKEN_END)`, which will terminate the current transcoding block.

!!! note
    Call `flush(stream)` after `write(stream, TOKEN_END)` to make sure that all data are written to the underlying stream.



<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/stream.jl#L283-L293' class='documenter-source'>source</a><br>


<a id='Defining-a-new-codec-1'></a>

## Defining a new codec

<a id='TranscodingStreams.Codec' href='#TranscodingStreams.Codec'>#</a>
**`TranscodingStreams.Codec`** &mdash; *Type*.



An abstract codec type.

Any codec supporting transcoding interfaces must be a subtype of this type.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/codec.jl#L4-L8' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.initialize' href='#TranscodingStreams.initialize'>#</a>
**`TranscodingStreams.initialize`** &mdash; *Function*.



```
initialize(codec::Codec)::Void
```

Initialize `codec`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/codec.jl#L15-L19' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.finalize' href='#TranscodingStreams.finalize'>#</a>
**`TranscodingStreams.finalize`** &mdash; *Function*.



```
finalize(codec::Codec)::Void
```

Finalize `codec`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/codec.jl#L24-L28' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.startproc' href='#TranscodingStreams.startproc'>#</a>
**`TranscodingStreams.startproc`** &mdash; *Function*.



```
startproc(codec::Codec, state::Symbol)::Symbol
```

Start data processing with `codec` of `state`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/codec.jl#L33-L37' class='documenter-source'>source</a><br>

<a id='TranscodingStreams.process' href='#TranscodingStreams.process'>#</a>
**`TranscodingStreams.process`** &mdash; *Function*.



```
process(codec::Codec, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}
```

Do data processing with `codec`.


<a target='_blank' href='https://github.com/bicycle1885/TranscodingStreams.jl/tree/2da95dabff9b7f56558d1ccecd13afad32e73af4/src/codec.jl#L42-L46' class='documenter-source'>source</a><br>

