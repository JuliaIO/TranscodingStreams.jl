# An insane codec for testing the codec APIs.
struct QuadrupleCodec <: TranscodingStreams.Codec end

function TranscodingStreams.process(
        codec  :: QuadrupleCodec,
        input  :: TranscodingStreams.Memory,
        output :: TranscodingStreams.Memory,
        error  :: TranscodingStreams.Error)
    i = j = 0
    while i + 1 ≤ lastindex(input) && j + 4 ≤ lastindex(output)
        b = input[i+1]
        i += 1
        output[j+1] = output[j+2] = output[j+3] = output[j+4] = b
        j += 4
    end
    return i, j, input.size == 0 ? (:end) : (:ok)
end

function TranscodingStreams.expectedsize(
              :: QuadrupleCodec,
        input :: TranscodingStreams.Memory)
    return input.size * 4
end

function TranscodingStreams.minoutsize(
        :: QuadrupleCodec,
        :: TranscodingStreams.Memory)
    return 4
end

@testset "Quadruple Codec" begin
    @test transcode(QuadrupleCodec, b"") == b""
    @test transcode(QuadrupleCodec, b"a") == b"aaaa"
    @test transcode(QuadrupleCodec, b"ab") == b"aaaabbbb"
    @test transcode(QuadrupleCodec(), b"") == b""
    @test transcode(QuadrupleCodec(), b"a") == b"aaaa"
    @test transcode(QuadrupleCodec(), b"ab") == b"aaaabbbb"

    #=
    data = "x"^1024
    transcode(QuadrupleCodec(), data)
    @test (@allocated transcode(QuadrupleCodec(), data)) < sizeof(data) * 5
    =#

    stream = TranscodingStream(QuadrupleCodec(), NoopStream(IOBuffer("foo")))
    @test read(stream) == b"ffffoooooooo"
    close(stream)

    stream = NoopStream(TranscodingStream(QuadrupleCodec(), NoopStream(IOBuffer("foo"))))
    @test read(stream) == b"ffffoooooooo"
    close(stream)

    stream = TranscodingStream(QuadrupleCodec(), IOBuffer("foo"))
    @test position(stream) === 0
    read(stream, 3)
    @test position(stream) === 3
    read(stream, UInt8)
    @test position(stream) === 4
    close(stream)

    stream = TranscodingStream(QuadrupleCodec(), IOBuffer())
    @test position(stream) === 0
    write(stream, 0x00)
    @test position(stream) === 1
    write(stream, "foo")
    @test position(stream) === 4
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

    stream = TranscodingStream(QuadrupleCodec(), IOBuffer("foo"))
    @test_throws EOFError unsafe_read(stream, pointer(Vector{UInt8}(undef, 13)), 13)
    close(stream)
end
