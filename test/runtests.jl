using TranscodingStreams
using Base.Test

@testset "Identity Codec" begin
    Identity = TranscodingStreams.Identity

    source = IOBuffer("")
    stream = TranscodingStream(Identity, source)
    @test eof(stream)
    @test read(stream) == UInt8[]
    close(stream)

    source = IOBuffer("foo")
    stream = TranscodingStream(Identity, source)
    @test !eof(stream)
    @test read(stream) == b"foo"
    close(stream)

    data = rand(UInt8, 100_000)
    source = IOBuffer(data)
    stream = TranscodingStream(Identity, source)
    @test !eof(stream)
    @test read(stream) == data
    close(stream)

    sink = IOBuffer()
    stream = TranscodingStream(Identity, sink)
    @test write(stream, "foo") === 3
    flush(stream)
    @test take!(sink) == b"foo"
    close(stream)

    data = rand(UInt8, 100_000)
    sink = IOBuffer()
    stream = TranscodingStream(Identity, sink)
    for i in 1:10_000
        @assert write(stream, data[10(i-1)+1:10i]) == 10
    end
    flush(stream)
    @test take!(sink) == data
    close(stream)
end
