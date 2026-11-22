using TranscodingStreams
using TestsForCodecPackages: TestsForCodecPackages
using Random
using Test
using Aqua: Aqua

Aqua.test_all(TranscodingStreams)
Aqua.test_all(TestsForCodecPackages)

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
    makemargin!, initbuffer!

@testset "Buffer" begin
    buf = Buffer(1024)
    @test buf isa Buffer
    @test length(buf.data) == 1024

    data = Vector{UInt8}(b"foobar")
    buf = Buffer(data)
    GC.@preserve data buf begin
        @test buf isa Buffer
        @test bufferptr(buf) === pointer(data)
        @test buffersize(buf) === 6
        @test buffermem(buf) === Memory(pointer(data), 6)
        @test marginptr(buf) === pointer(data) + 6
        @test marginsize(buf) === 0
        @test marginmem(buf) === Memory(pointer(data)+6, 0)
    end

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
    initbuffer!(buf)
    @test makemargin!(buf, 0) === margin_size + 2
end

@testset "Memory" begin
    data = Vector{UInt8}(b"foobar")
    GC.@preserve data let mem = TranscodingStreams.Memory(pointer(data), sizeof(data))
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
    end

    data = Vector{UInt8}(b"foobar")
    GC.@preserve data let mem = TranscodingStreams.Memory(pointer(data), sizeof(data))
        @test mem isa TranscodingStreams.Memory
        @test mem.ptr == pointer(data)
        @test mem.size == sizeof(data)
    end
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

# Buffer interface
# ----------------

using TranscodingStreams: peekavailable, fillavailable!, consume!

# Read `stream` as a parser would: buffer more until the chunk ends at a newline, and take whole lines from the buffer.
function read_lines_in_place(stream)
    lines = String[]
    while true
        available = peekavailable(stream)
        newline = findfirst(==(UInt8('\n')), available)
        if newline === nothing
            fillavailable!(stream) == 0 || continue
            isempty(available) || push!(lines, String(copy(available)))
            break
        end
        push!(lines, String(copy(available[1:newline-1])))
        consume!(stream, newline)
    end
    return lines
end

@testset "Buffer interface" begin
    lines = [repeat(string(i), i) for i in 1:200]
    lines[50] = repeat("x", 100_000) # longer than any buffer
    text = join(lines, '\n')

    for bufsize in (1, 16, 2^16)
        @test read_lines_in_place(NoopStream(IOBuffer(text); bufsize)) == lines
        # Nested noop streams share one buffer.
        @test read_lines_in_place(NoopStream(NoopStream(IOBuffer(text); bufsize); bufsize)) == lines
        # A codec with buffers of its own, which writes four bytes for each, newlines included.
        stream = TranscodingStream(QuadrupleCodec(), IOBuffer(text); bufsize)
        @test read_lines_in_place(stream) == split(String(transcode(QuadrupleCodec, Vector{UInt8}(text))), '\n')
    end

    # Filling keeps the bytes that are buffered, and appends to them.
    stream = NoopStream(IOBuffer("foobar"); bufsize = 2)
    @test isempty(peekavailable(stream))
    @test fillavailable!(stream) == 2
    @test peekavailable(stream) == b"fo"
    @test fillavailable!(stream) > 0
    @test startswith(String(copy(peekavailable(stream))), "foo")
    # Consuming moves on in the buffer, and `position` follows.
    consume!(stream, 1)
    @test position(stream) == 1
    @test bytesavailable(stream) == length(peekavailable(stream))
    while fillavailable!(stream) > 0 end
    @test peekavailable(stream) == b"oobar"
    @test fillavailable!(stream) == 0
    @test read(stream) == b"oobar"
    @test eof(stream) && isempty(peekavailable(stream)) && fillavailable!(stream) == 0
    # Only the bytes that are buffered can be consumed, and only by a reading stream.
    @test_throws ArgumentError consume!(stream, 1)
    @test_throws ArgumentError consume!(stream, -1)
    consume!(stream, 0)
    close(stream)
    writing = NoopStream(IOBuffer())
    write(writing, "abc")
    @test_throws ArgumentError consume!(writing, 1)
    close(writing)

    # An empty stream.
    stream = NoopStream(IOBuffer(""))
    @test fillavailable!(stream) == 0 && isempty(peekavailable(stream))
    close(stream)

    # A codec stops at its end, after which nothing is filled.
    stream = TranscodingStream(QuadrupleCodec(), IOBuffer("ab"); stop_on_end = true)
    while fillavailable!(stream) > 0 end
    @test peekavailable(stream) == b"aaaabbbb"
    @test fillavailable!(stream) == 0
    close(stream)
end
