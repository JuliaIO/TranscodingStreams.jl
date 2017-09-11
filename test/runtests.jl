using TranscodingStreams
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

    data = b"foobar"
    mem = TranscodingStreams.Memory(data)
    @test mem isa TranscodingStreams.Memory
    @test mem.ptr == pointer(data)
    @test mem.size == sizeof(data)
end

@testset "Noop Codec" begin
    source = IOBuffer("")
    stream = TranscodingStream(Noop(), source)
    @test eof(stream)
    @test read(stream) == UInt8[]
    @test contains(repr(stream), "mode=read")

    source = IOBuffer("foo")
    stream = TranscodingStream(Noop(), source)
    @test !eof(stream)
    @test read(stream) == b"foo"
    close(stream)

    data = rand(UInt8, 100_000)
    source = IOBuffer(data)
    stream = TranscodingStream(Noop(), source)
    @test !eof(stream)
    @test read(stream) == data
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer())
    @test_throws EOFError read(stream, UInt8)
    @test_throws EOFError unsafe_read(stream, pointer(Vector{UInt8}(3)), 3)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer("foobar"), bufsize=1)
    @test read(stream, UInt8) === UInt8('f')
    data = Vector{UInt8}(5)
    unsafe_read(stream, pointer(data), 5) === nothing
    @test data == b"oobar"
    close(stream)

    sink = IOBuffer()
    stream = TranscodingStream(Noop(), sink)
    @test write(stream, "foo") === 3
    @test contains(repr(stream), "mode=write")
    flush(stream)
    @test take!(sink) == b"foo"
    close(stream)

    data = rand(UInt8, 100_000)
    sink = IOBuffer()
    stream = TranscodingStream(Noop(), sink)
    for i in 1:10_000
        @assert write(stream, data[10(i-1)+1:10i]) == 10
    end
    flush(stream)
    @test take!(sink) == data
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer(b"foobarbaz"))
    @test position(stream) === 0
    read(stream, UInt8)
    @test position(stream) === 1
    read(stream)
    @test position(stream) === 9

    data = collect(0x00:0x0f)
    stream = TranscodingStream(Noop(), IOBuffer(data))
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

    stream = TranscodingStream(Noop(), IOBuffer(b"foobarbaz"))
    seek(stream, 2)
    @test read(stream, 3) == b"oba"
    seek(stream, 0)
    @test read(stream, 3) == b"foo"
    seekstart(stream)
    @test read(stream, 3) == b"foo"
    seekend(stream)
    @test eof(stream)
    close(stream)

    data = collect(0x00:0x0f)
    stream = TranscodingStream(Noop(), IOBuffer(data))
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
    stream = TranscodingStream(Noop(), IOBuffer(data), bufsize=2)
    @test read(stream, UInt8) == data[1]
    skip(stream, 4)
    @test read(stream, UInt8) == data[6]
    skip(stream, 3)
    @test read(stream, UInt8) == data[10]
    skip(stream, 6)
    @test eof(stream)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer("foo"))
    read(stream, UInt8)
    @test_throws ArgumentError skip(stream, -1)
    skip(stream, 100)
    @test eof(stream)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer("foo"))
    out = zeros(UInt8, 3)
    @test nb_available(stream) == 0
    @test TranscodingStreams.unsafe_read(stream, pointer(out), 10) == 3
    @test out == b"foo"
    close(stream)

    s = TranscodingStream(Noop(), IOBuffer(b"baz"))
    @test endof(s.state.buffer1) == 0
    read(s, UInt8)
    @test endof(s.state.buffer1) == 2
    @test s.state.buffer1[1] === UInt8('a')
    @test s.state.buffer1[2] === UInt8('z')
    @test s.state.buffer1[1:2] == b"az"
    @test_throws BoundsError s.state.buffer1[0]
    @test_throws BoundsError s.state.buffer1[3]
    @test_throws BoundsError s.state.buffer1[3:4]
    close(s)

    data = rand(UInt8, 1999)
    # unmarked
    stream = TranscodingStream(Noop(), IOBuffer(data), bufsize=7)
    @test hash(read(stream)) == hash(data)
    @test length(stream.state.buffer1) == 7
    # marked
    stream = TranscodingStream(Noop(), IOBuffer(data), bufsize=7)
    mark(stream)
    @test hash(read(stream)) == hash(data)
    @test hash(stream.state.buffer1.data[1:length(data)]) == hash(data)
    close(stream)

    stream = NoopStream(NoopStream(IOBuffer("foobar")))
    @test read(stream) == b"foobar"
    close(stream)

    stream = NoopStream(NoopStream(NoopStream(IOBuffer("foobar"))))
    @test read(stream) == b"foobar"
    close(stream)

    # Two buffers are the same object.
    stream = NoopStream(IOBuffer("foo"))
    @test stream.state.buffer1 === stream.state.buffer2

    # Nested NoopStreams share the same buffer.
    s0 = IOBuffer("foo")
    s1 = NoopStream(s0)
    s2 = NoopStream(s1)
    s3 = NoopStream(s2)
    @test s1.state.buffer1 === s2.state.buffer1 === s3.state.buffer1 ===
          s1.state.buffer2 === s2.state.buffer2 === s3.state.buffer2

    #= FIXME: restore these tests
    stream = TranscodingStream(Noop(), IOBuffer(b"foobar"))
    @test TranscodingStreams.total_in(stream) === Int64(0)
    @test TranscodingStreams.total_out(stream) === Int64(0)
    read(stream)
    @test TranscodingStreams.total_in(stream) === Int64(6)
    @test TranscodingStreams.total_out(stream) === Int64(6)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer())
    @test TranscodingStreams.total_in(stream) === Int64(0)
    @test TranscodingStreams.total_out(stream) === Int64(0)
    write(stream, b"foobar")
    flush(stream)
    @test TranscodingStreams.total_in(stream) === Int64(6)
    @test TranscodingStreams.total_out(stream) === Int64(6)
    close(stream)
    =#

    stream = NoopStream(IOBuffer("foobar"))
    @test nb_available(stream) === 0
    @test readavailable(stream) == b""
    @test read(stream, UInt8) === UInt8('f')
    @test nb_available(stream) === 5
    @test readavailable(stream) == b"oobar"
    close(stream)

    data = b""
    @test transcode(Noop, data)  == data
    @test transcode(Noop, data) !== data
    data = b"foo"
    @test transcode(Noop, data)  == data
    @test transcode(Noop, data) !== data

    data = b""
    @test transcode(Noop(), data)  == data
    @test transcode(Noop(), data) !== data
    data = b"foo"
    @test transcode(Noop(), data)  == data
    @test transcode(Noop(), data) !== data

    TranscodingStreams.test_roundtrip_transcode(Noop, Noop)
    TranscodingStreams.test_roundtrip_read(NoopStream, NoopStream)
    TranscodingStreams.test_roundtrip_write(NoopStream, NoopStream)
    TranscodingStreams.test_roundtrip_lines(NoopStream, NoopStream)

    # switch write => read
    stream = NoopStream(IOBuffer(b"foobar", true, true))
    @test_throws ArgumentError begin
        write(stream, b"xyz")
        read(stream, 3)
    end

    # switch read => write
    stream = NoopStream(IOBuffer(b"foobar", true, true))
    @test_throws ArgumentError begin
        read(stream, 3)
        write(stream, b"xyz")
    end

    stream = NoopStream(IOBuffer(""))
    @test TranscodingStreams.unread(stream, b"foo") === nothing
    @test read(stream, 3) == b"foo"
    close(stream)

    stream = NoopStream(IOBuffer("foo"))
    @test read(stream, 3) == b"foo"
    @test TranscodingStreams.unread(stream, b"bar") === nothing
    @test read(stream, 3) == b"bar"
    close(stream)

    stream = NoopStream(IOBuffer("foobar"))
    @test TranscodingStreams.unread(stream, b"baz") === nothing
    @test read(stream, 3) == b"baz"
    @test read(stream, 3) == b"foo"
    @test read(stream, 3) == b"bar"
    @test eof(stream)
    close(stream)

    stream = NoopStream(IOBuffer("foobar"))
    @test read(stream, 3) == b"foo"
    @test TranscodingStreams.unread(stream, b"baz") === nothing
    @test read(stream, 3) == b"baz"
    @test read(stream, 3) == b"bar"
    @test eof(stream)
    close(stream)

    stream = NoopStream(IOBuffer("foobar"))
    @test read(stream, 3) == b"foo"
    @test read(stream, 3) == b"bar"
    @test TranscodingStreams.unread(stream, b"baz") === nothing
    @test read(stream, 3) == b"baz"
    @test eof(stream)
    close(stream)

    stream = NoopStream(IOBuffer("foobar"))
    @test_throws ArgumentError TranscodingStreams.unsafe_unread(stream, pointer(b"foo"), -1)
    close(stream)

    stream = NoopStream(IOBuffer(""))
    @test eof(stream)  # idle
    unsafe_write(stream, C_NULL, 0)
    @test eof(stream)  # write
    close(stream)
    @test eof(stream)  # close

    @test_throws ArgumentError NoopStream(IOBuffer(), bufsize=0)
    @test_throws ArgumentError NoopStream(let s = IOBuffer(); close(s); s; end)
    @test_throws ArgumentError TranscodingStream(Noop(), IOBuffer(), bufsize=0)
    @test_throws ArgumentError TranscodingStream(Noop(), IOBuffer(), sharedbuf=true)
end

# This does not implement necessary interface methods.
struct InvalidCodec <: TranscodingStreams.Codec end

@testset "Invalid Codec" begin
    @test_throws MethodError read(TranscodingStream(InvalidCodec(), IOBuffer()))
end

struct QuadrupleCodec <: TranscodingStreams.Codec end

const Memory = TranscodingStreams.Memory
function TranscodingStreams.process(
        codec  :: QuadrupleCodec,
        input  :: Memory,
        output :: Memory,
        error  :: TranscodingStreams.Error)
    i = j = 0
    while i + 1 ≤ endof(input) && j + 4 ≤ endof(output)
        b = input[i+1]
        i += 1
        output[j+1] = output[j+2] = output[j+3] = output[j+4] = b
        j += 4
    end
    return i, j, input.size == 0 ? (:end) : (:ok)
end

TranscodingStreams.expectedsize(::QuadrupleCodec, input::Memory) = input.size * 4
TranscodingStreams.minoutsize(::QuadrupleCodec, ::Memory) = 4

@testset "QuadrupleCodec" begin
    @test transcode(QuadrupleCodec, b"") == b""
    @test transcode(QuadrupleCodec, b"a") == b"aaaa"
    @test transcode(QuadrupleCodec, b"ab") == b"aaaabbbb"
    @test transcode(QuadrupleCodec(), b"") == b""
    @test transcode(QuadrupleCodec(), b"a") == b"aaaa"
    @test transcode(QuadrupleCodec(), b"ab") == b"aaaabbbb"

    data = "x"^1024
    transcode(QuadrupleCodec(), data)
    @test (@allocated transcode(QuadrupleCodec(), data)) < sizeof(data) * 5

    stream = TranscodingStream(QuadrupleCodec(), NoopStream(IOBuffer("foo")))
    @test read(stream) == b"ffffoooooooo"
    close(stream)

    stream = NoopStream(TranscodingStream(QuadrupleCodec(), NoopStream(IOBuffer("foo"))))
    @test read(stream) == b"ffffoooooooo"
    close(stream)

    # Buffers are shared.
    stream1 = TranscodingStream(QuadrupleCodec(), IOBuffer("foo"))
    stream2 = TranscodingStream(QuadrupleCodec(), stream1)
    @test stream1.state.buffer1 === stream2.state.buffer2
    close(stream1)
    close(stream2)

    # Explicitly unshare buffers.
    stream1 = TranscodingStream(QuadrupleCodec(), IOBuffer("foo"))
    stream2 = TranscodingStream(QuadrupleCodec(), stream1, sharedbuf=false)
    @test stream1.state.buffer1 !== stream2.state.buffer2
    close(stream1)
    close(stream2)
end

# TODO: Remove this in the future.
using TranscodingStreams.CodecIdentity
@testset "Identity Codec (deprecated)" begin
    TranscodingStreams.test_roundtrip_transcode(Identity, Identity)
    TranscodingStreams.test_roundtrip_read(IdentityStream, IdentityStream)
    TranscodingStreams.test_roundtrip_write(IdentityStream, IdentityStream)
    TranscodingStreams.test_roundtrip_lines(IdentityStream, IdentityStream)
end

for pkg in ["CodecZlib", "CodecBzip2", "CodecXz", "CodecZstd", "CodecBase"]
    Pkg.test(pkg)
end
