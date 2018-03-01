using TranscodingStreams
using Compat
if VERSION > v"0.7-"
    using Test
else
    using Base.Test
end

# Tool tests
# ----------

import TranscodingStreams:
    Buffer, Memory,
    bufferptr, buffersize, buffermem,
    marginptr, marginsize, marginmem,
    readbyte!, writebyte!,
    #=ismarked,=# mark!, unmark!, reset!,
    makemargin!, emptybuffer!

# HACK: Overload b"..." syntax for v0.7/v1.0 compatibility.
macro b_str(data)
    convert(Vector{UInt8}, codeunits(data))
end

@testset "Buffer" begin
    buf = Buffer(1024)
    @test buf isa Buffer
    @test length(buf.data) == 1024

    data = b"foobar"
    buf = Buffer(data)
    @test buf isa Buffer
    @test bufferptr(buf) === pointer(data)
    @test buffersize(buf) === 6
    @test buffermem(buf) === Memory(pointer(data), 6)
    @test marginptr(buf) === pointer(data) + 6
    @test marginsize(buf) === 0
    @test marginmem(buf) === Memory(pointer(data)+6, 0)

    buf = Buffer(2)
    writebyte!(buf, 0x34)
    writebyte!(buf, 0x9f)
    @test buffersize(buf) === 2
    @test readbyte!(buf) === 0x34
    @test readbyte!(buf) === 0x9f
    @test buffersize(buf) === 0

    buf = Buffer(16)
    @test !TranscodingStreams.ismarked(buf)
    @test mark!(buf) == 1
    @test TranscodingStreams.ismarked(buf)
    @test unmark!(buf)
    @test !TranscodingStreams.ismarked(buf)
    @test !unmark!(buf)

    buf = Buffer(16)
    mark!(buf)
    writebyte!(buf, 0x34)
    writebyte!(buf, 0x99)
    reset!(buf)
    @test !TranscodingStreams.ismarked(buf)
    @test readbyte!(buf) === 0x34
    @test readbyte!(buf) === 0x99

    buf = Buffer(16)
    @test makemargin!(buf, 0) === 16
    writebyte!(buf, 0x34)
    @test makemargin!(buf, 0) === 15
    writebyte!(buf, 0x99)
    @test makemargin!(buf, 20) === 20
    emptybuffer!(buf)
    @test makemargin!(buf, 0) === 22
end

@testset "Memory" begin
    data = b"foobar"
    mem = TranscodingStreams.Memory(pointer(data), sizeof(data))
    @test mem isa TranscodingStreams.Memory
    @test mem.ptr === pointer(data)
    @test mem.size === length(mem) === UInt(sizeof(data))
    @test lastindex(mem) === 6
    @test mem[1] === UInt8('f')
    @test mem[2] === UInt8('o')
    @test mem[3] === UInt8('o')
    @test mem[4] === UInt8('b')
    @test mem[5] === UInt8('a')
    @test mem[6] === UInt8('r')
    @test_throws BoundsError mem[7]
    @test_throws BoundsError mem[0]
    mem[1] = UInt8('z')
    @test mem[1] === UInt8('z')
    mem[3] = UInt8('!')
    @test mem[3] === UInt8('!')
    @test_throws BoundsError mem[7] = 0x00
    @test_throws BoundsError mem[0] = 0x00

    data = b"foobar"
    mem = TranscodingStreams.Memory(data)
    @test mem isa TranscodingStreams.Memory
    @test mem.ptr == pointer(data)
    @test mem.size == sizeof(data)
end

@testset "Stats" begin
    stats = TranscodingStreams.Stats(1,2,3,4)
    @test repr(stats) ==
    """
    TranscodingStreams.Stats:
      in: 1
      out: 2
      transcoded_in: 3
      transcoded_out: 4"""
    @test stats.in == 1
    @test stats.out == 2
    @test stats.transcoded_in == 3
    @test stats.transcoded_out == 4
end

@testset "Utils" begin
    @test TranscodingStreams.splitkwargs(
        [(:foo, 1), (:bar, true), (:baz, :ok)], (:foo,)) ==
        ([(:foo, 1)], [(:bar, true), (:baz, :ok)])
end


# Codec tests
# -----------

include("codecnoop.jl")
include("codecinvalid.jl")
include("codecquadruple.jl")
include("codecidentity.jl")  # deprecated codec

# Test third-party codec packages.
for pkg in ["CodecZlib", "CodecBzip2", "CodecXz", "CodecZstd", "CodecBase"]
    Pkg.test(pkg)
end

# TODO: This should be moved to CodecZlib.jl.
import CodecZlib
import CodecZlib: GzipCompressor, GzipDecompressor
TranscodingStreams.test_chunked_read(GzipCompressor, GzipDecompressor)
TranscodingStreams.test_chunked_write(GzipCompressor, GzipDecompressor)
TranscodingStreams.test_roundtrip_fileio(GzipCompressor, GzipDecompressor)

@testset "seek" begin
    data = transcode(GzipCompressor, b"abracadabra")
    stream = TranscodingStream(GzipDecompressor(), IOBuffer(data))
    seekstart(stream)
    @test read(stream, 3) == b"abr"
    seekstart(stream)
    @test read(stream, 3) == b"abr"
    seekend(stream)
    #@test eof(stream)
end

@testset "panic" begin
    stream = TranscodingStream(GzipDecompressor(), IOBuffer("some invalid data"))
    @test_throws ErrorException read(stream)
    @test_throws ArgumentError eof(stream)
end

@testset "open" begin
    open(CodecZlib.GzipDecompressorStream, joinpath(dirname(@__FILE__), "abra.gzip")) do stream
        @test read(stream) == b"abracadabra"
    end
end

@testset "stats" begin
    size = filesize(joinpath(dirname(@__FILE__), "abra.gzip"))
    stream = CodecZlib.GzipDecompressorStream(open(joinpath(dirname(@__FILE__), "abra.gzip")))
    stats = TranscodingStreams.stats(stream)
    @test stats.in == 0
    @test stats.out == 0
    @test stats.transcoded_in == 0
    @test stats.transcoded_out == 0
    read(stream, UInt8)
    stats = TranscodingStreams.stats(stream)
    @test stats.in == size
    @test stats.out == 1
    @test stats.transcoded_in == size
    @test stats.transcoded_out == 11
    close(stream)
    @test_throws ArgumentError TranscodingStreams.stats(stream)

    buf = IOBuffer()
    stream = CodecZlib.GzipCompressorStream(buf)
    stats = TranscodingStreams.stats(stream)
    @test stats.in == 0
    @test stats.out == 0
    @test stats.transcoded_in == 0
    @test stats.transcoded_out == 0
    write(stream, b"abracadabra")
    stats = TranscodingStreams.stats(stream)
    @test stats.in == 11
    @test stats.out == 0
    @test stats.transcoded_in == 0
    @test stats.transcoded_out == 0
    write(stream, TranscodingStreams.TOKEN_END)
    flush(stream)
    stats = TranscodingStreams.stats(stream)
    @test stats.in == 11
    @test stats.out == position(buf)
    @test stats.transcoded_in == 11
    @test stats.transcoded_out == position(buf)
    close(stream)
    @test_throws ArgumentError TranscodingStreams.stats(stream)
end
