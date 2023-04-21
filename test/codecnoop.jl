@testset "Noop Codec" begin
    source = IOBuffer("")
    stream = TranscodingStream(Noop(), source)
    @test eof(stream)
    @inferred eof(stream)
    @test read(stream) == UInt8[]
    @test occursin("mode=read", repr(stream))

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
    @test_throws EOFError unsafe_read(stream, pointer(Vector{UInt8}(undef, 3)), 3)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer("foobar"), bufsize=1)
    @test read(stream, UInt8) === UInt8('f')
    data = Vector{UInt8}(undef, 5)
    unsafe_read(stream, pointer(data), 5) === nothing
    @test data == b"oobar"
    close(stream)

    sink = IOBuffer()
    stream = TranscodingStream(Noop(), sink)
    @test write(stream, "foo") === 3
    @test occursin("mode=write", repr(stream))
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
    @test bytesavailable(stream) == 0
    @test TranscodingStreams.unsafe_read(stream, pointer(out), 10) == 3
    @test out == b"foo"
    close(stream)

    data = rand(UInt8, 1999)
    # unmarked
    stream = TranscodingStream(Noop(), IOBuffer(data), bufsize=7)
    @test hash(read(stream)) == hash(data)
    @test length(stream.state.buffer1.data) == 7
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

    stream = TranscodingStream(Noop(), IOBuffer(b"foobar"))
    @test TranscodingStreams.stats(stream).in === Int64(0)
    @test TranscodingStreams.stats(stream).out === Int64(0)
    read(stream)
    @test TranscodingStreams.stats(stream).in === Int64(6)
    @test TranscodingStreams.stats(stream).out === Int64(6)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer())
    @test TranscodingStreams.stats(stream).in === Int64(0)
    @test TranscodingStreams.stats(stream).out === Int64(0)
    write(stream, b"foobar")
    flush(stream)
    @test TranscodingStreams.stats(stream).in === Int64(6)
    @test TranscodingStreams.stats(stream).out === Int64(6)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer())
    @test stream.state.mode == :idle
    @test write(stream) == 0
    @test stream.state.mode == :write
    close(stream)

    stream = NoopStream(IOBuffer("foobar"))
    @test bytesavailable(stream) === 0
    @test readavailable(stream) == b""
    @test read(stream, UInt8) === UInt8('f')
    @test bytesavailable(stream) === 5
    @test readavailable(stream) == b"oobar"
    close(stream)

    data = b""
    @test transcode(Noop, data)  == data
    @test transcode(Noop, data) !== data
    data = b"foo"
    @test transcode(Noop, data)  == data
    @test transcode(Noop, data) !== data

    data = Vector{UInt8}()
    @test TranscodingStreams.unsafe_transcode!(Noop(), data, data) == data
    @test_throws AssertionError transcode(Noop(), data, data)
    data = b""
    @test transcode(Noop(), data)  == data
    @test transcode(Noop(), data) !== data
    @test transcode(Noop(), data, Vector{UInt8}()) == data
    @test transcode(Noop(), data, TranscodingStreams.Buffer(Vector{UInt8}())) == data
    @test transcode(Noop(), data, Vector{UInt8}()) !== data
    @test transcode(Noop(), data, TranscodingStreams.Buffer(Vector{UInt8}())) !== data
    output = Vector{UInt8}()
    @test transcode(Noop(), data, output) === output
    output = TranscodingStreams.Buffer(Vector{UInt8}())
    @test transcode(Noop(), data, output) === output.data

    data = b"foo"
    @test transcode(Noop(), data)  == data
    @test transcode(Noop(), data) !== data
    @test transcode(Noop(), data, Vector{UInt8}()) == data
    @test transcode(Noop(), data, TranscodingStreams.Buffer(Vector{UInt8}())) == data
    @test transcode(Noop(), data, Vector{UInt8}()) !== data
    @test transcode(Noop(), data, TranscodingStreams.Buffer(Vector{UInt8}())) !== data
    output = Vector{UInt8}()
    @test transcode(Noop(), data, output) === output
    output = TranscodingStreams.Buffer(Vector{UInt8}())
    @test transcode(Noop(), data, output) === output.data

    data = ""
    @test String(transcode(Noop, data)) == data
    data = "foo"
    @test String(transcode(Noop, data)) == data

    TranscodingStreams.test_roundtrip_transcode(Noop, Noop)
    TranscodingStreams.test_roundtrip_read(NoopStream, NoopStream)
    TranscodingStreams.test_roundtrip_write(NoopStream, NoopStream)
    TranscodingStreams.test_roundtrip_lines(NoopStream, NoopStream)

    # switch write => read
    stream = NoopStream(IOBuffer(b"foobar", read=true, write=true))
    @test_throws ArgumentError begin
        write(stream, b"xyz")
        read(stream, 3)
    end

    # switch read => write
    stream = NoopStream(IOBuffer(b"foobar", read=true, write=true))
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
    unsafe_write(stream, C_NULL, 0)
    @test eof(stream)  # write
    close(stream)
    @test eof(stream)  # close

    @testset "readuntil" begin
        stream = NoopStream(IOBuffer(""))
        data = readuntil(stream, 0x00)
        @test data isa Vector{UInt8}
        @test isempty(data)

        stream = NoopStream(IOBuffer("foo,bar"))
        @test readuntil(stream, UInt8(',')) == b"foo"
        @test read(stream) == b"bar"

        stream = NoopStream(IOBuffer("foo,bar"))
        @test readuntil(stream, UInt8(','), keep = false) == b"foo"
        @test read(stream) == b"bar"

        stream = NoopStream(IOBuffer("foo,bar"))
        @test readuntil(stream, UInt8(','), keep = true) == b"foo,"
        @test read(stream) == b"bar"
    end

    @test_throws ArgumentError NoopStream(IOBuffer(), bufsize=0)
    @test_throws ArgumentError NoopStream(let s = IOBuffer(); close(s); s; end)
    @test_throws ArgumentError TranscodingStream(Noop(), IOBuffer(), bufsize=0)
    @test_throws ArgumentError TranscodingStream(Noop(), IOBuffer(), sharedbuf=true)

    @testset "position" begin
        iob = IOBuffer()
        sink = IOBuffer()
        stream = NoopStream(sink, bufsize=16)
        @test position(stream) == position(iob)
        for len in 0:10:100
            write(stream, repeat("x", len))
            write(iob, repeat("x", len))
            @test position(stream) == position(iob)
        end
        @test position(stream) == position(sink) == position(iob)
        close(stream)
        close(iob)

        mktemp() do path, sink
            stream = NoopStream(sink, bufsize=16)
            pos = 0
            for len in 0:10:100
                write(stream, repeat("x", len))
                pos += len
                @test position(stream) == pos
            end
        end
    end
end
