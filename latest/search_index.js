var documenterSearchIndex = {"docs": [

{
    "location": "index.html#",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.jl",
    "category": "page",
    "text": ""
},

{
    "location": "index.html#TranscodingStreams.jl-1",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.jl",
    "category": "section",
    "text": "TranscodingStreams.jl is a package for transcoding (e.g. compression) data streams. This package exports a type TranscodingStream, which is a subtype of IO and supports various I/O operations like other usual I/O streams in the standard library."
},

{
    "location": "index.html#Introduction-1",
    "page": "TranscodingStreams.jl",
    "title": "Introduction",
    "category": "section",
    "text": "TranscodingStream has two type parameters, C<:Codec and S<:IO, and hence the actual type should be written as TranscodingStream{C<:Codec,S<:IO}. This type wraps an underlying I/O stream S by a codec C. The codec defines transformation (or transcoding) of the stream. For example, when C is a lossless decompression type and S is a file, TranscodingStream{C,S} behaves like a data stream that incrementally decompresses data from the file.Codecs are defined in other packages listed below:<table>\n    <tr>\n        <th>Package</th>\n        <th>Library</th>\n        <th>Format</th>\n        <th>Codec</th>\n        <th>Stream</th>\n        <th>Description</th>\n    </tr>\n    <tr>\n        <td rowspan=\"6\"><a href=\"https://github.com/bicycle1885/CodecZlib.jl\">CodecZlib.jl</a></td>\n        <td rowspan=\"6\"><a href=\"http://zlib.net/\">zlib</a></td>\n        <td rowspan=\"2\"><a href=\"https://tools.ietf.org/html/rfc1952\">RFC1952</a></td>\n        <td><code>GzipCompression</code></td>\n        <td><code>GzipCompressionStream</code></td>\n        <td>Compress data in gzip (.gz) format.</td>\n    </tr>\n    <tr>\n        <td><code>GzipDecompression</code></td>\n        <td><code>GzipDecompressionStream</code></td>\n        <td>Decompress data in gzip (.gz) format.</td>\n    </tr>\n    <tr>\n        <td rowspan=\"2\"><a href=\"https://tools.ietf.org/html/rfc1950\">RFC1950</a></td>\n        <td><code>ZlibCompression</code></td>\n        <td><code>ZlibCompressionStream</code></td>\n        <td>Compress data in zlib format.</td>\n    </tr>\n    <tr>\n        <td><code>ZlibDecompression</code></td>\n        <td><code>ZlibDecompressionStream</code></td>\n        <td>Decompress data in zlib format.</td>\n    </tr>\n    <tr>\n        <td rowspan=\"2\"><a href=\"https://tools.ietf.org/html/rfc1951\">RFC1951</a></td>\n        <td><code>DeflateCompression</code></td>\n        <td><code>DeflateCompressionStream</code></td>\n        <td>Compress data in deflate format.</td>\n    </tr>\n    <tr>\n        <td><code>DeflateDecompression</code></td>\n        <td><code>DeflateDecompressionStream</code></td>\n        <td>Decompress data in deflate format.</td>\n    </tr>\n    <tr>\n        <td rowspan=\"2\"><a href=\"https://github.com/bicycle1885/CodecBzip2.jl\">CodecBzip2.jl</a></td>\n        <td rowspan=\"2\"><a href=\"http://www.bzip.org/\">bzip2</a></td>\n        <td rowspan=\"2\"></td>\n        <td><code>Bzip2Compression</code></td>\n        <td><code>Bzip2CompressionStream</code></td>\n        <td>Compress data in bzip2 (.bz2) format.</td>\n    </tr>\n    <tr>\n        <td><code>Bzip2Decompression</code></td>\n        <td><code>Bzip2DecompressionStream</code></td>\n        <td>Decompress data in bzip2 (.bz2) format.</td>\n    </tr>\n    <tr>\n        <td rowspan=\"2\"><a href=\"https://github.com/bicycle1885/CodecXz.jl\">CodecXz.jl</a></td>\n        <td rowspan=\"2\"><a href=\"https://tukaani.org/xz/\">xz</a></td>\n        <td rowspan=\"2\"><a href=\"https://tukaani.org/xz/xz-file-format.txt\">The .xz File Format</a></td>\n        <td><code>XzCompression</code></td>\n        <td><code>XzCompressionStream</code></td>\n        <td>Compress data in xz (.xz) format.</td>\n    </tr>\n    <tr>\n        <td><code>XzDecompression</code></td>\n        <td><code>XzDecompressionStream</code></td>\n        <td>Decompress data in xz (.xz) format.</td>\n    </tr>\n    <tr>\n        <td rowspan=\"2\"><a href=\"https://github.com/bicycle1885/CodecZstd.jl\">CodecZstd.jl</a></td>\n        <td rowspan=\"2\"><a href=\"http://facebook.github.io/zstd/\">zstd</a></td>\n        <td rowspan=\"2\"><a href=\"https://github.com/facebook/zstd/blob/dev/doc/zstd_compression_format.md\">Zstandard Compression Format</a></td>\n        <td><code>ZstdCompression</code></td>\n        <td><code>ZstdCompressionStream</code></td>\n        <td>Compress data in zstd (.zst) format.</td>\n    </tr>\n    <tr>\n        <td><code>ZstdDecompression</code></td>\n        <td><code>ZstdDecompressionStream</code></td>\n        <td>Decompress data in zstd (.zst) format.</td>\n    </tr>\n</table>Install packages you need by calling Pkg.add(<package name>) in a Julia session. For example, if you want to read gzip-compressed files, call Pkg.add(\"CodecZlib\") to use GzipDecompression or GzipDecompressionStream. By convention, codec types have a name that matches .*(Co|Deco)mpression and I/O types have a codec name with Stream suffix. All codecs are a subtype TranscodingStreams.Codec and streams are a subtype of Base.IO. An important thing is these packages depend on TranscodingStreams.jl and not vice versa. This means you can install any codec package you need without installing all codec packages.  Also, if you want to define your own codec, it is totally feasible like these packages.  TranscodingStreams.jl requests a codec to implement some interface functions which will be described later."
},

{
    "location": "index.html#Examples-1",
    "page": "TranscodingStreams.jl",
    "title": "Examples",
    "category": "section",
    "text": ""
},

{
    "location": "index.html#Read-lines-from-a-gzip-compressed-file-1",
    "page": "TranscodingStreams.jl",
    "title": "Read lines from a gzip-compressed file",
    "category": "section",
    "text": "The following snippet is an example of using CodecZlib.jl, which exports GzipDecompressionStream{S} as an alias of TranscodingStream{GzipDecompression,S} where S<:IO:using CodecZlib\nstream = GzipDecompressionStream(open(\"data.txt.gz\"))\nfor line in eachline(stream)\n    # do something...\nend\nclose(stream)Note that the last close call will close the file as well.  Alternatively, open(<stream type>, <filepath>) do ... end syntax will close the file at the end:using CodecZlib\nopen(GzipDecompressionStream, \"data.txt.gz\") do stream\n    for line in eachline(stream)\n        # do something...\n    end\nend"
},

{
    "location": "index.html#Save-a-data-matrix-with-Zstd-compression-1",
    "page": "TranscodingStreams.jl",
    "title": "Save a data matrix with Zstd compression",
    "category": "section",
    "text": "Writing compressed data is easy. One thing you need to keep in mind is to call close after writing data; otherwise, the output file will be incomplete:using CodecZstd\nmat = randn(100, 100)\nstream = ZstdCompressionStream(open(\"data.mat.zst\", \"w\"))\nwritedlm(stream, mat)\nclose(stream)Of course, open(<stream type>, ...) do ... end works well:using CodecZstd\nmat = randn(100, 100)\nopen(ZstdCompressionStream, \"data.mat.zst\", \"w\") do stream\n    writedlm(stream, mat)\nend"
},

{
    "location": "index.html#Explicitly-finish-transcoding-by-writing-TOKEN_END-1",
    "page": "TranscodingStreams.jl",
    "title": "Explicitly finish transcoding by writing TOKEN_END",
    "category": "section",
    "text": "When writing data, the end of a data stream is indicated by calling close, which may write an epilogue if necessary and flush all buffered data to the underlying I/O stream. If you want to explicitly specify the end position of a stream for some reason, you can write TranscodingStreams.TOKEN_END to the transcoding stream as follows:using CodecZstd\nusing TranscodingStreams\nbuf = IOBuffer()\nstream = ZstdCompressionStream(buf)\nwrite(stream, \"foobarbaz\"^100, TranscodingStreams.TOKEN_END)\nflush(stream)\ncompressed = take!(buf)\nclose(stream)"
},

{
    "location": "index.html#Use-an-identity-(no-op)-codec-1",
    "page": "TranscodingStreams.jl",
    "title": "Use an identity (no-op) codec",
    "category": "section",
    "text": "Sometimes, the Identity codec, which does nothing, may be useful. The following example creates a decompression stream based on the extension of a filepath:using CodecZlib\nusing CodecBzip2\nusing TranscodingStreams\nusing TranscodingStreams.CodecIdentity\n\nfunction makestream(filepath)\n    if endswith(filepath, \".gz\")\n        codec = GzipDecompression()\n    elseif endswith(filepath, \".bz2\")\n        codec = Bzip2Decompression()\n    else\n        codec = Identity()\n    end\n    return TranscodingStream(codec, open(filepath))\nend\n\nmakestream(\"data.txt.gz\")\nmakestream(\"data.txt.bz2\")\nmakestream(\"data.txt\")"
},

{
    "location": "index.html#Transcode-data-in-one-shot-1",
    "page": "TranscodingStreams.jl",
    "title": "Transcode data in one shot",
    "category": "section",
    "text": "TranscodingStreams.jl extends the transcode function to transcode a data in one shot. transcode takes a codec object as its first argument and a data vector as its second argument:using CodecZlib\ndecompressed = transcode(ZlibDecompression(), b\"x\\x9cKL*JLNLI\\x04R\\x00\\x19\\xf2\\x04U\")\nString(decompressed)"
},

{
    "location": "index.html#TranscodingStreams.TranscodingStream-Tuple{TranscodingStreams.Codec,IO}",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.TranscodingStream",
    "category": "Method",
    "text": "TranscodingStream(codec::Codec, stream::IO; bufsize::Integer=16384)\n\nCreate a transcoding stream with codec and stream.\n\nExamples\n\njulia> using TranscodingStreams\n\njulia> using CodecZlib\n\njulia> file = open(Pkg.dir(\"TranscodingStreams\", \"test\", \"abra.gzip\"));\n\njulia> stream = TranscodingStream(GzipDecompression(), file)\nTranscodingStreams.TranscodingStream{CodecZlib.GzipDecompression,IOStream}(<state=idle>)\n\njulia> readstring(stream)\n\"abracadabra\"\n\n\n\n\n"
},

{
    "location": "index.html#Base.transcode-Tuple{TranscodingStreams.Codec,Array{UInt8,1}}",
    "page": "TranscodingStreams.jl",
    "title": "Base.transcode",
    "category": "Method",
    "text": "transcode(codec::Codec, data::Vector{UInt8})::Vector{UInt8}\n\nTranscode data by applying codec.\n\nExamples\n\njulia> using CodecZlib\n\njulia> data = Vector{UInt8}(\"abracadabra\");\n\njulia> compressed = transcode(ZlibCompression(), data);\n\njulia> decompressed = transcode(ZlibDecompression(), compressed);\n\njulia> String(decompressed)\n\"abracadabra\"\n\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.TOKEN_END",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.TOKEN_END",
    "category": "Constant",
    "text": "A special token indicating the end of data.\n\nTOKEN_END may be written to a transcoding stream like write(stream, TOKEN_END), which will terminate the current transcoding block.\n\nnote: Note\nCall flush(stream) after write(stream, TOKEN_END) to make sure that all data are written to the underlying stream.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.CodecIdentity.Identity",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.CodecIdentity.Identity",
    "category": "Type",
    "text": "Identity()\n\nCreate an identity (no-op) codec.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.CodecIdentity.IdentityStream",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.CodecIdentity.IdentityStream",
    "category": "Type",
    "text": "IdentityStream(stream::IO)\n\nCreate an identity (no-op) stream.\n\n\n\n"
},

{
    "location": "index.html#API-1",
    "page": "TranscodingStreams.jl",
    "title": "API",
    "category": "section",
    "text": "CurrentModule = TranscodingStreamsTranscodingStream(codec::Codec, stream::IO)\ntranscode(codec::Codec, data::Vector{UInt8})\nTranscodingStreams.TOKEN_ENDTranscodingStreams.CodecIdentity.Identity\nTranscodingStreams.CodecIdentity.IdentityStream"
},

{
    "location": "index.html#TranscodingStreams.Codec",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.Codec",
    "category": "Type",
    "text": "An abstract codec type.\n\nAny codec supporting the transcoding protocol must be a subtype of this type.\n\nTranscoding protocol\n\nTranscoding proceeds by calling some functions in a specific way. We call this \"transcoding protocol\" and any codec must implement it as described below.\n\nThere are four functions for a codec to implement:\n\ninitialize: initialize the codec\nfinalize: finalize the codec\nstartproc: start processing with the codec\nprocess: process data with the codec.\n\nThese are defined in the TranscodingStreams and a new codec type must extend these methods if necessary.  Implementing a process method is mandatory but other three are optional.  initialize, finalize, and startproc have a default implementation that does nothing.\n\nYour codec type is denoted by C and its object by codec.\n\nThe initialize(codec::C)::Void method takes codec and returns nothing. This is called once and only once before starting any data processing.  Therefore, you may initialize codec (e.g. allocating memory needed to process data) with this method. If initialization fails for some reason, it may throw an exception and no other methods will be called.\n\nThe finalize(codec::C)::Void method takes codec and returns nothing.  This is called when and only when the transcoding stream goes to the close state (i.e. when Base.close is called). Therefore, you may finalize codec (e.g. freeing memory) with this method. If finalization fails for some reason, it may throw an exception. Even when an exception is thrown while finalizing a stream, the stream will become the close state for safety.\n\nThe startproc(codec::C, state::Symbol)::Symbol method takes codec and state, and returns a status code. This is called just before the stream starts reading or writing data. state is either :read or :write and then the stream starts reading or writing, respectively. The return code must be :ok if codec is ready to read or write data. Otherwise, it should be :fail and then the stream throws an exception.\n\nThe process(codec::C, input::Memory, output::Memory)::Tuple{Int,Int,Symbol} method takes codec, input and output, and returns a consumed data size, a produced data size and a status code. This is called repeatedly while processing data. The input (input) and output (output) data are a Memory object, which is a pointer to a contiguous memory region with size. You must read input data from input, transcode the bytes, and then write the output data to output.  Finally you need to return the size of read data, the size of written data, and :ok status code so that the caller can know how many bytes are consumed and produced in the method.  When transcoding reaches the end of a data stream, it is notified to this method by empty input. In that case, the method need to write the buffered data (if any) to output. If there is no data to write, the status code must be set to :end. The process method will be called repeatedly until it returns :end status code.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.initialize",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.initialize",
    "category": "Function",
    "text": "initialize(codec::Codec)::Void\n\nInitialize codec.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.finalize",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.finalize",
    "category": "Function",
    "text": "finalize(codec::Codec)::Void\n\nFinalize codec.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.startproc",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.startproc",
    "category": "Function",
    "text": "startproc(codec::Codec, state::Symbol)::Symbol\n\nStart data processing with codec of state.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.process",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.process",
    "category": "Function",
    "text": "process(codec::Codec, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}\n\nDo data processing with codec.\n\n\n\n"
},

{
    "location": "index.html#TranscodingStreams.Memory",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.Memory",
    "category": "Type",
    "text": "A contiguous memory.\n\nThis type works like a Vector method.\n\n\n\n"
},

{
    "location": "index.html#Defining-a-new-codec-1",
    "page": "TranscodingStreams.jl",
    "title": "Defining a new codec",
    "category": "section",
    "text": "TranscodingStreams.Codec\nTranscodingStreams.initialize\nTranscodingStreams.finalize\nTranscodingStreams.startproc\nTranscodingStreams.processTranscodingStreams.Memory"
},

]}
