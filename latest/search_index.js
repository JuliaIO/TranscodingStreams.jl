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
    "text": "TranscodingStream has two type parameters, C<:Codec and S<:IO, and hence the actual type should be written as TranscodingStream{C<:Codec,S<:IO}. This type wraps an underlying I/O stream S by a codec C. The codec defines transformation (or transcoding) of the stream. For example, when C is a lossless decompression type and S is a file, TranscodingStream{C,S} behaves like a data stream that incrementally decompresses data from the file.Codecs are defined in other packages listed below:CodecZlib.jl\nGizipCompression (GzipCompressionStream)\nGzipDecompression (GzipDecompressionStream)\nZlibCompression (ZlibCompressionStream)\nZlibDecompression (ZlibDecompressionStream)\nDeflateCompression (DeflateCompressionStream)\nDeflateDecompression (DeflateDecompressionStream)\nCodecZstd.jl\nZstdCompression (ZstdCompressionStream)\nZstdDecompression (ZstdDecompressionStream)\nCodecBzip2.jl\nBzip2Compression (Bzip2CompressionStream)\nBzip2Decompression (Bzip2DecompressionStream)By convention, codec types have a name that matches .*(Co|Deco)mpression and I/O types have a codec name with Stream suffix.  An important thing is these packages depend on TranscodingStreams.jl and not vice versa. This means you can install any codec package you need without installing all codec packages. Also, if you want to define your own codec, it is totally feasible like these packages.  TranscodingStreams.jl requests a codec to implement some interface functions which will be described later."
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
    "location": "index.html#API-1",
    "page": "TranscodingStreams.jl",
    "title": "API",
    "category": "section",
    "text": "CurrentModule = TranscodingStreamsTranscodingStream(codec::Codec, stream::IO)\ntranscode(codec::Codec, data::Vector{UInt8})\nTranscodingStreams.TOKEN_END"
},

{
    "location": "index.html#TranscodingStreams.Codec",
    "page": "TranscodingStreams.jl",
    "title": "TranscodingStreams.Codec",
    "category": "Type",
    "text": "An abstract codec type.\n\nAny codec supporting transcoding interfaces must be a subtype of this type.\n\n\n\n"
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
    "location": "index.html#Defining-a-new-codec-1",
    "page": "TranscodingStreams.jl",
    "title": "Defining a new codec",
    "category": "section",
    "text": "TranscodingStreams.Codec\nTranscodingStreams.initialize\nTranscodingStreams.finalize\nTranscodingStreams.startproc\nTranscodingStreams.process"
},

]}
