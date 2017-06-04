using TranscodingStreams
using Base.Test

@testset "Identity Codec" begin
    Identity = TranscodingStreams.Identity

    source = IOBuffer("")
    stream = TranscodingStream(Identity(), source)
    @test eof(stream)
    @test read(stream) == UInt8[]
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

    sink = IOBuffer()
    stream = TranscodingStream(Identity(), sink)
    @test write(stream, "foo") === 3
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

    data = collect(0x00:0x0f)
    stream = TranscodingStream(Identity(), IOBuffer(data))
    @test read(stream, UInt8) == data[1]
    skip(stream, 1)
    @test read(stream, UInt8) == data[3]
    skip(stream, 5)
    @test read(stream, UInt8) == data[9]

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

    # transcode
    @test transcode(Identity(), b"") == b""
    @test transcode(Identity(), b"foo") == b"foo"
    TranscodingStreams.test_roundtrip_transcode(Identity, Identity)
end

installed = keys(Pkg.installed())
for pkg in ["CodecZlib", "CodecZstd", "CodecBzip2"]
    if pkg ∉ installed
        # TODO: ad-hoc fix
        Pkg.clone("https://github.com/bicycle1885/$(pkg).jl")
    end
    Pkg.test(pkg)
end
