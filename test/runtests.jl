using TranscodingStreams
using TranscodingStreams.CodecIdentity
using Base.Test

@testset "Memory" begin
    data = b"foobar"
    mem = TranscodingStreams.Memory(pointer(data), sizeof(data))
    @test mem isa TranscodingStreams.Memory
    @test mem.ptr === pointer(data)
    @test mem.size === length(mem) === UInt(sizeof(data))
    @test endof(mem) === 6
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

@testset "Identity Codec" begin
    source = IOBuffer("")
    stream = TranscodingStream(Identity(), source)
    @test eof(stream)
    @test read(stream) == UInt8[]
    @test contains(repr(stream), "state=read")
    close(stream)

    source = IOBuffer("foo")
    stream = TranscodingStream(Identity(), source)
    @test !eof(stream)
    @test read(stream) == b"foo"
    close(stream)

    data = rand(UInt8, 100_000)
    source = IOBuffer(data)
    stream = TranscodingStream(Identity(), source)
    @test !eof(stream)
    @test read(stream) == data
    close(stream)

    stream = TranscodingStream(Identity(), IOBuffer())
    @test_throws EOFError read(stream, UInt8)
    @test_throws EOFError unsafe_read(stream, pointer(Vector{UInt8}(3)), 3)
    close(stream)

    # switch write => read
    buf = IOBuffer(b"foobar", true, true)
    stream = TranscodingStream(Identity(), buf)
    @test write(stream, b"xyz") == 3
    @test read(stream, 3) == b"bar"
    @test take!(buf) == b"xyzbar"
    close(stream)

    sink = IOBuffer()
    stream = TranscodingStream(Identity(), sink)
    @test write(stream, "foo") === 3
    @test contains(repr(stream), "state=write")
    flush(stream)
    @test take!(sink) == b"foo"
    close(stream)

    data = rand(UInt8, 100_000)
    sink = IOBuffer()
    stream = TranscodingStream(Identity(), sink)
    for i in 1:10_000
        @assert write(stream, data[10(i-1)+1:10i]) == 10
    end
    flush(stream)
    @test take!(sink) == data
    close(stream)

    data = collect(0x00:0x0f)
    stream = TranscodingStream(Identity(), IOBuffer(data))
    @test !ismarked(stream)
    mark(stream)
    @test ismarked(stream)
    @test [read(stream, UInt8) for _ in 1:3] == data[1:3]
    reset(stream)
    @test !ismarked(stream)
    @test [read(stream, UInt8) for _ in 1:3] == data[1:3]
    mark(stream)
    @test ismarked(stream)
    unmark(stream)
    @test !ismarked(stream)
    close(stream)

    data = collect(0x00:0x0f)
    stream = TranscodingStream(Identity(), IOBuffer(data))
    @test read(stream, UInt8) == data[1]
    skip(stream, 1)
    @test read(stream, UInt8) == data[3]
    skip(stream, 5)
    @test read(stream, UInt8) == data[9]
    skip(stream, 7)
    @test eof(stream)
    close(stream)

    # skip offset > bufsize
    data = collect(0x00:0x0f)
    stream = TranscodingStream(Identity(), IOBuffer(data), bufsize=2)
    @test read(stream, UInt8) == data[1]
    skip(stream, 4)
    @test read(stream, UInt8) == data[6]
    skip(stream, 3)
    @test read(stream, UInt8) == data[10]
    skip(stream, 6)
    @test eof(stream)
    close(stream)

    stream = TranscodingStream(Identity(), IOBuffer("foo"))
    out = zeros(UInt8, 3)
    @test nb_available(stream) == 0
    @test TranscodingStreams.unsafe_read(stream, pointer(out), 10) == 3
    @test out == b"foo"
    close(stream)

    s = TranscodingStream(Identity(), IOBuffer(b"baz"))
    @test endof(s.state.buffer1) == 0
    read(s, UInt8)
    @test endof(s.state.buffer1) == 2
    @test s.state.buffer1[1] === UInt8('a')
    @test s.state.buffer1[2] === UInt8('z')
    @test s.state.buffer1[1:2] == b"az"
    @test_throws BoundsError s.state.buffer1[0]
    @test_throws BoundsError s.state.buffer1[3]
    @test_throws BoundsError s.state.buffer1[3:4]

    data = rand(UInt8, 1999)
    # unmarked
    stream = TranscodingStream(Identity(), IOBuffer(data), bufsize=7)
    @test hash(read(stream)) == hash(data)
    @test length(stream.state.buffer1) == 7
    # marked
    stream = TranscodingStream(Identity(), IOBuffer(data), bufsize=7)
    mark(stream)
    @test hash(read(stream)) == hash(data)
    @test hash(stream.state.buffer1.data[1:length(data)]) == hash(data)

    stream = TranscodingStream(Identity(), IOBuffer(b"foobar"))
    @test TranscodingStreams.total_in(stream) === Int64(0)
    @test TranscodingStreams.total_out(stream) === Int64(0)
    read(stream)
    @test TranscodingStreams.total_in(stream) === Int64(6)
    @test TranscodingStreams.total_out(stream) === Int64(6)

    stream = TranscodingStream(Identity(), IOBuffer())
    @test TranscodingStreams.total_in(stream) === Int64(0)
    @test TranscodingStreams.total_out(stream) === Int64(0)
    write(stream, b"foobar")
    flush(stream)
    @test TranscodingStreams.total_in(stream) === Int64(6)
    @test TranscodingStreams.total_out(stream) === Int64(6)

    # transcode
    @test transcode(Identity(), b"") == b""
    @test transcode(Identity(), b"foo") == b"foo"
    TranscodingStreams.test_roundtrip_transcode(Identity, Identity)

    TranscodingStreams.test_roundtrip_read(IdentityStream, IdentityStream)
    TranscodingStreams.test_roundtrip_write(IdentityStream, IdentityStream)
    TranscodingStreams.test_roundtrip_lines(IdentityStream, IdentityStream)

    @test_throws ArgumentError TranscodingStream(Identity(), IOBuffer(), bufsize=0)
end

# This does not implement necessary interface methods.
struct InvalidCodec <: TranscodingStreams.Codec end

@testset "Invalid Codec" begin
    @test_throws MethodError read(TranscodingStream(InvalidCodec(), IOBuffer()))
end

for pkg in ["CodecZlib", "CodecBzip2", "CodecXz", "CodecZstd"]
    Pkg.test(pkg)
end
