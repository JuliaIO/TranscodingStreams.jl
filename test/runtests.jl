using TranscodingStreams
using Random
using Test
using Aqua: Aqua

Aqua.test_all(TranscodingStreams)

@test isempty(detect_unbound_args(TranscodingStreams; recursive=true))
@test isempty(detect_ambiguities(TranscodingStreams; recursive=true))

# Tool tests
# ----------

using TranscodingStreams:
    Buffer, Memory,
    bufferptr, buffersize, buffermem,
    marginptr, marginsize, marginmem,
    readbyte!, writebyte!,
    #=ismarked,=# mark!, unmark!, reset!,
    makemargin!, emptybuffer!

@testset "Buffer" begin
    buf = Buffer(1024)
    @test buf isa Buffer
    @test length(buf.data) == 1024

    data = Vector{UInt8}(b"foobar")
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
    margin_size = makemargin!(buf, 20) 
    @test margin_size >= 20
    emptybuffer!(buf)
    @test makemargin!(buf, 0) === margin_size + 2
end

@testset "Memory" begin
    data = Vector{UInt8}(b"foobar")
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

    data = Vector{UInt8}(b"foobar")
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
include("codecdoubleframe.jl")