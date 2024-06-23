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

# Read data using various means.
# These function read a vector of bytes from io,
# if io is eof they should return an empty vector.
read_methods = Data.SampledFrom([
    function read_byte(io)
        eof(io) && return UInt8[]
        [read(io, UInt8)]
    end,
    function read_by_readuntil_keep(io)
        delim = 0x01
        readuntil(io, delim; keep=true)
    end,
    function read_by_Base_unsafe_read(io)
        n = bytesavailable(io)
        ret = zeros(UInt8, n)
        GC.@preserve ret Base.unsafe_read(io, pointer(ret), n)
        ret
    end,
    function read_by_readavailable(io)
        readavailable(io)
    end,
    function read_by_readbytes1(io)
        ret = zeros(UInt8, 10000)
        n = readbytes!(io, ret)
        ret[1:n]
    end,
    function read_by_readbytes2(io)
        ret = zeros(UInt8, 0)
        n = readbytes!(io, ret, 10000)
        ret[1:n]
    end
])

# Return true if the stats of a stream are self consistent
# This function assumes stream was never seeked.
function is_stats_consistent(stream)
    if stream isa TranscodingStream
        s = TranscodingStreams.stats(stream)
        inner_pos = position(stream.stream)
        pos = position(stream)
        # event!("stats(stream)", s)
        # event!("position(stream.stream)", inner_pos)
        # event!("position(stream)", pos)
        if isreadable(stream)
            s.out == pos || return false
            s.in == inner_pos || return false
        else
            iswritable(stream) || return false
            s.in == pos || return false
            s.out == inner_pos || return false
        end
        s.transcoded_in ≤ s.in || return false
        s.transcoded_out ≥ s.out || return false
    end
    true
end

@testset "read" begin
    @check function read_byte_data(
            kws=read_codecs_kws,
            data=datas,
        )
        stream = wrap_stream(kws, IOBuffer(data))
        for i in 1:length(data)
            position(stream) == i-1 || return false
            is_stats_consistent(stream) || return false
            read(stream, UInt8) == data[i] || return false
        end
        is_stats_consistent(stream) || return false
        eof(stream)
    end
    @check function read_data(
            kws=read_codecs_kws,
            data=datas,
        )
        stream = wrap_stream(kws, IOBuffer(data))
        read(stream) == data || return false
        is_stats_consistent(stream) || return false
        eof(stream)
    end
    @check function read_data_methods(
            kws=read_codecs_kws,
            data=datas,
            rs=Data.Vectors(read_methods),
        )
        stream = wrap_stream(kws, IOBuffer(data))
        x = UInt8[]
        for r in rs
            d = r(stream)
            append!(x, d)
            length(x) == position(stream) || return false
        end
        is_stats_consistent(stream) || return false
        x == data[eachindex(x)]
    end
end

# flush all nested streams and return final data
function take_all(stream)
    if stream isa Base.GenericIOBuffer
        seekstart(stream)
        read(stream)
    else
        write(stream, TranscodingStreams.TOKEN_END)
        flush(stream)
        take_all(stream.stream)
    end
end

const write_codecs_kws = map(reverse, read_codecs_kws)

@testset "write" begin
    @check function write_data(
            kws=write_codecs_kws,
            data=datas,
        )
        stream = wrap_stream(kws, IOBuffer())
        write(stream, data) == length(data) || return false
        take_all(stream) == data || return false
        is_stats_consistent(stream) || return false
        true
    end
    @check function write_byte_data(
            kws=write_codecs_kws,
            data=datas,
        )
        stream = wrap_stream(kws, IOBuffer())
        for i in 1:length(data)
            position(stream) == i-1 || return false
            is_stats_consistent(stream) || return false
            write(stream, data[i]) == 1 || return false
        end
        take_all(stream) == data || return false
        is_stats_consistent(stream) || return false
        true
    end
end