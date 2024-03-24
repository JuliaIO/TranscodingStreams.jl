# Basic Supposition.jl tests to ensure nested streams can be read and written to.

using Supposition: Data, @composed, @check, event!, produce!

include("../test/codecdoubleframe.jl")

const TS_kwarg = @composed (
    bufsize=Data.Integers(1, 2^10),
    stop_on_end=Data.Booleans(),
    sharedbuf=Data.Booleans(),
) -> (
    if sharedbuf
        # default sharedbuf
        (;bufsize, stop_on_end)
    else
        # sharedbuf = false
        (;bufsize, stop_on_end, sharedbuf)
    end
)

const datas = Data.Vectors(Data.Integers{UInt8}())
const noopcodecs = Data.Vectors(Data.Just(Noop); max_size=3)

function codecwrap(child)
    map(child) do x
        DataType[
            DoubleFrameEncoder;
            x;
            DoubleFrameDecoder;
        ]
    end | map(Data.Vectors(child; min_size=2, max_size=2)) do x
        reduce(vcat, x)
    end
end

# possible vector of codec types that when read from
# should be equivalent to a Noop. 
# Every encoder is balanced with a decoder.
const codecs = Data.Recursive(noopcodecs, codecwrap; max_layers=4)

function prepare_kws(codecs)
    # res will be a nicely printed summary of the layers of the stream.
    res = []
    for codec in codecs
        kw = Data.produce!(TS_kwarg)
        push!(res, (codec, kw))
    end
    res
end

const read_codecs_kws = map(prepare_kws, codecs)

function wrap_stream(codecs_kws, io::IO)::IO
    event!("IOBuffer:", nothing)
    foldl(codecs_kws; init=io) do stream, (codec, kw)
        event!("codec:", (codec, kw))
        TranscodingStream(codec(), stream; kw...)
    end
end

@check function read_byte_data(
        kws=read_codecs_kws,
        data=datas,
    )
    stream = wrap_stream(kws, IOBuffer(data))
    for i in eachindex(data)
        read(stream, UInt8) == data[i] || return false
    end
    eof(stream)
end
@check function read_data(
        kws=read_codecs_kws,
        data=datas,
    )
    stream = wrap_stream(kws, IOBuffer(data))
    read(stream) == data || return false
    eof(stream)
end

# flush all nested streams and return final data
function take_all(stream)
    if stream isa Base.GenericIOBuffer
        take!(stream)
    else
        write(stream, TranscodingStreams.TOKEN_END)
        flush(stream)
        take_all(stream.stream)
    end
end

const write_codecs_kws = map(reverse, read_codecs_kws)

@check function write_data(
        kws=write_codecs_kws,
        data=datas,
    )
    stream = wrap_stream(kws, IOBuffer())
    write(stream, data) == length(data) || return false
    take_all(stream) == data
end
@check function write_byte_data(
        kws=write_codecs_kws,
        data=datas,
    )
    stream = wrap_stream(kws, IOBuffer())
    for i in 1:length(data)
        write(stream, data[i]) == 1 || return false
    end
    take_all(stream) == data
end