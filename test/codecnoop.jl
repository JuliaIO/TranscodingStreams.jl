using OffsetArrays: OffsetArray
using FillArrays: Zeros
using TestsForCodecPackages:
    test_roundtrip_read,
    test_roundtrip_write,
    test_roundtrip_transcode,
    test_roundtrip_lines,
    test_roundtrip_seekstart,
    test_roundtrip_fileio,
    test_chunked_read,
    test_chunked_write

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
    data = Vector{UInt8}(undef, 3)
    @test_throws EOFError GC.@preserve data unsafe_read(stream, pointer(data), 3)
    close(stream)

    stream = TranscodingStream(Noop(), IOBuffer("foobar"), bufsize=1)
    @test read(stream, UInt8) === UInt8('f')
    data = Vector{UInt8}(undef, 5)
    GC.@preserve data unsafe_read(stream, pointer(data), 5) === nothing
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
    @test position(stream) === Int64(0)
    read(stream, UInt8)
    @test position(stream) === Int64(1)
    read(stream)
    @test position(stream) === Int64(9)

    data = collect(0x00:0x0f)
    stream = TranscodingStream(Noop(), IOBuffer(data))
    @test !ismarked(stream)
    @test mark(stream) == 0
    @test ismarked(stream)
    @test [read(stream, UInt8) for _ in 1:3] == data[1:3]
    @test reset(stream) == 0
    @test_throws ArgumentError reset(stream)
    @test !ismarked(stream)
    @test [read(stream, UInt8) for _ in 1:3] == data[1:3]
    @test mark(stream) == 3
    @test ismarked(stream)
    @test unmark(stream)
    @test !ismarked(stream)
    @test !unmark(stream)
    @test mark(stream) == 3
    close(stream)
    @test !ismarked(stream)

    stream = TranscodingStream(Noop(), IOBuffer(b"foobarbaz"))
    @test stream == seek(stream, 2)
    @test read(stream, 3) == b"oba"
    seek(stream, 0)
    @test read(stream, 3) == b"foo"
    @test stream == seekstart(stream)
    @test read(stream, 3) == b"foo"
    @test stream == seekend(stream)
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
    @test stream == skip(stream, 4)
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
    @test GC.@preserve out TranscodingStreams.unsafe_read(stream, pointer(out), 10) == 3
    @test out == b"foo"
    close(stream)

    data = rand(UInt8, 1999)
    # unmarked
    stream = TranscodingStream(Noop(), IOBuffer(data), bufsize=7)
    @test hash(read(stream)) == hash(data)
    @test length(stream.buffer1.data) == 7
    # marked
    stream = TranscodingStream(Noop(), IOBuffer(data), bufsize=7)
    mark(stream)
    @test hash(read(stream)) == hash(data)
    @test hash(stream.buffer1.data[1:length(data)]) == hash(data)
    close(stream)

    stream = NoopStream(NoopStream(IOBuffer("foobar")))
    @test read(stream) == b"foobar"
    close(stream)

    stream = NoopStream(NoopStream(NoopStream(IOBuffer("foobar"))))
    @test read(stream) == b"foobar"
    close(stream)

    stream = NoopStream(NoopStream(IOBuffer("foobar")); sharedbuf=false)
    @test read(stream) == b"foobar"
    close(stream)

    stream = NoopStream(NoopStream(IOBuffer("foobar")); sharedbuf=false)
    @test map(x->read(stream, UInt8), 1:6) == b"foobar"
    @test eof(stream)
    close(stream)

    stream = NoopStream(NoopStream(NoopStream(IOBuffer("foobar")); sharedbuf=false))
    @test read(stream) == b"foobar"
    close(stream)

    # Two buffers are the same object.
    stream = NoopStream(IOBuffer("foo"))
    @test stream.buffer1 === stream.buffer2

    # Nested NoopStreams share the same buffer.
    s0 = IOBuffer("foo")
    s1 = NoopStream(s0)
    s2 = NoopStream(s1)
    s3 = NoopStream(s2)
    @test s1.buffer1 === s2.buffer1 === s3.buffer1 ===
          s1.buffer2 === s2.buffer2 === s3.buffer2

    @testset "stats" begin
        stream = TranscodingStream(Noop(), IOBuffer(b"foobar"))
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(0)
        @test stat.out === Int64(0)
        eof(stream)
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(0)
        read(stream)
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(6)
        close(stream)

        #nested NoopStreams
        stream = NoopStream(NoopStream(IOBuffer(b"foobar")))
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(0)
        @test stat.out === Int64(0)
        eof(stream)
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(0)
        @test stat.out === Int64(0)
        read(stream)
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(6)
        close(stream)

        stream = TranscodingStream(Noop(), IOBuffer())
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(0)
        @test stat.out === Int64(0)
        write(stream, b"foobar")
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(0)
        flush(stream)
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(6)
        close(stream)

        #nested NoopStreams
        stream = NoopStream(NoopStream(IOBuffer()))
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(0)
        @test stat.out === Int64(0)
        write(stream, b"foobar")
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(6)
        flush(stream)
        stat = TranscodingStreams.stats(stream)
        @test stat.in === Int64(6)
        @test stat.out === Int64(6)
        close(stream)
    end

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

    # issue #193
    stream = NoopStream(IOBuffer("foobar"))
    data = UInt8[]
    @test readbytes!(stream, data, 1) === 1
    @test data == b"f"
    @test position(stream) == 1
    close(stream)

    data = b""
    @test transcode(Noop, data)  == data
    @test transcode(Noop, data) !== data
    data = b"foo"
    @test transcode(Noop, data)  == data
    @test transcode(Noop, data) !== data

    data = UInt8[]
    @test TranscodingStreams.unsafe_transcode!(Noop(), data, data) == data
    data = [0x01, 0x02]
    @test_throws ErrorException transcode(Noop(), data, data)
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

    test_roundtrip_transcode(Noop, Noop)
    test_roundtrip_read(NoopStream, NoopStream)
    test_roundtrip_write(NoopStream, NoopStream)
    test_roundtrip_lines(NoopStream, NoopStream)
    test_roundtrip_seekstart(NoopStream, NoopStream)

    @testset "switch write => read" begin
        stream = NoopStream(IOBuffer(collect(b"foobar"), read=true, write=true))
        @test isreadable(stream)
        @test iswritable(stream)
        @test_throws ArgumentError begin
            write(stream, b"xyz")
            read(stream, 3)
        end
        @test !isreadable(stream)
        @test iswritable(stream)
    end

    @testset "switch read => write" begin
        stream = NoopStream(IOBuffer(collect(b"foobar"), read=true, write=true))
        @test_throws ArgumentError begin
            read(stream, 3)
            write(stream, b"xyz")
        end
        @test isreadable(stream)
        @test !iswritable(stream)
    end

    @testset "unread" begin
        stream = NoopStream(IOBuffer(""))
        @test TranscodingStreams.unread(stream, b"foo") === nothing
        @test position(stream) == -3
        @test read(stream, 3) == b"foo"
        @test position(stream) == 0
        @test eof(stream)
        close(stream)

        stream = NoopStream(IOBuffer("foo"))
        @test read(stream, 3) == b"foo"
        @test position(stream) == 3
        @test TranscodingStreams.unread(stream, b"bar") === nothing
        @test position(stream) == 0
        @test read(stream, 3) == b"bar"
        @test position(stream) == 3
        @test eof(stream)
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
        @test position(stream) == 0
        @test read(stream, 3) == b"foo"
        @test position(stream) == 3
        @test read(stream, 3) == b"bar"
        @test position(stream) == 6
        @test TranscodingStreams.unread(stream, b"baz") === nothing
        @test position(stream) == 3
        @test read(stream, 3) == b"baz"
        @test position(stream) == 6
        @test eof(stream)
        @test position(stream) == 6
        close(stream)

        for bufsize in (1, 2, 3, 4, 100)
            for n in (1, 100)
                stream = NoopStream(IOBuffer("foo"^n*"bar"^n); bufsize)
                @test mark(stream) == 0
                @test position(stream) == 0
                @test read(stream, 3n) == codeunits("foo"^n)
                @test read(stream, 3n) == codeunits("bar"^n)
                @test position(stream) == 6n
                TranscodingStreams.unread(stream, codeunits("baz"^n))
                @test position(stream) == 3n
                @test reset(stream) == 0
                @test position(stream) == 0
                @test read(stream, 3n) == codeunits("foo"^n)
                @test read(stream, 3n) == codeunits("baz"^n)
                @test position(stream) == 6n
                @test eof(stream)
                @test position(stream) == 6n
                close(stream)
            end
        end

        # unread before mark
        stream = NoopStream(IOBuffer("foobar"); bufsize=16)
        @test read(stream, String) == "foobar"
        mark(stream)
        for i in 1:100
            TranscodingStreams.unread(stream, b"foo")
        end
        @test read(stream, String) == "foo"^100
        @test reset(stream) == 6
        @test eof(stream)

        stream = NoopStream(IOBuffer("foobar"))
        data = b"foo"
        @test_throws ArgumentError GC.@preserve data TranscodingStreams.unsafe_unread(stream, pointer(data), -1)
        close(stream)

        stream = NoopStream(IOBuffer("foo"))
        @test read(stream, 3) == b"foo"
        @test TranscodingStreams.unread(stream, OffsetArray(b"bar", -5:-3)) === nothing
        @test read(stream, 3) == b"bar"
        close(stream)

        stream = NoopStream(IOBuffer("foobar"))
        @test read(stream, 3) == b"foo"
        @test_throws OverflowError TranscodingStreams.unread(stream, Zeros{UInt8}(typemax(Int))) === nothing
        close(stream)

        stream = NoopStream(IOBuffer("foo"))
        @test read(stream, 3) == b"foo"
        @test TranscodingStreams.unread(stream, Zeros{UInt8}(big(3))) === nothing
        @test read(stream, 3) == b"\0\0\0"
        close(stream)

        stream = NoopStream(IOBuffer("foo"))
        @test read(stream, 3) == b"foo"
        d = b"bar"
        GC.@preserve d begin
            @test TranscodingStreams.unsafe_unread(stream, pointer(d), 3) === nothing
        end
        @test read(stream, 3) == b"bar"
        close(stream)

        stream = NoopStream(IOBuffer())
        write(stream, b"foo")
        @test_throws ArgumentError TranscodingStreams.unread(stream, b"bar")
        close(stream)
    end

    stream = NoopStream(IOBuffer(""))
    unsafe_write(stream, C_NULL, 0)
    @test_throws ArgumentError eof(stream)  # write
    close(stream)
    @test_throws ArgumentError eof(stream)  # close

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
        @test_throws ArgumentError position(stream)
        @test_throws ArgumentError TranscodingStreams.stats(stream)
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

        @testset "writing nested NoopStream sharedbuf=$(sharedbuf)" for sharedbuf in (true, false)
            stream = NoopStream(NoopStream(IOBuffer()); sharedbuf, bufsize=4)
            @test position(stream) == 0
            write(stream, 0x01)
            @test position(stream) == 1
            flush(stream)
            @test position(stream) == 1
            write(stream, "abc")
            @test position(stream) == 4
            flush(stream)
            @test position(stream) == 4
            for i in 1:10
                write(stream, 0x01)
                @test position(stream) == 4 + i
            end
        end

        @testset "reading nested NoopStream sharedbuf=$(sharedbuf)" for sharedbuf in (true, false)
            stream = NoopStream(NoopStream(IOBuffer("abcdefghijk")); sharedbuf, bufsize=4)
            @test position(stream) == 0
            @test !eof(stream)
            @test position(stream) == 0
            @test read(stream, UInt8) == b"a"[1]
            @test position(stream) == 1
            @test read(stream, 3) == b"bcd"
            @test position(stream) == 4
            @test !eof(stream)
            @test position(stream) == 4
            @test read(stream) == b"efghijk"
            @test position(stream) == 11
            @test eof(stream)
            @test position(stream) == 11
        end

    end

    @testset "seek doesn't delete data" begin
        sink = IOBuffer()
        stream = NoopStream(sink, bufsize=16)
        write(stream, "x")
        seekstart(stream)
        flush(stream)
        @test take!(sink) == b"x"
        close(stream)

        op_expected = [
            (seekstart, b"dbc"),
            (seekend, b"abcd"),
            (Base.Fix2(seek, 1), b"adc"),
        ]
        @testset "$op" for (op, expected) in op_expected
            sink = IOBuffer()
            stream = NoopStream(sink, bufsize=16)
            write(stream, "abc")
            @test op(stream) === stream
            write(stream, "d")
            flush(stream)
            @test take!(sink) == expected
            close(stream)
        end
    end

    @testset "stop_on_end=true prevents underlying stream closing" begin
        sink = IOBuffer()
        stream = NoopStream(sink, stop_on_end=true)
        write(stream, "abcd")
        close(stream)
        @test isopen(sink)
        @test take!(sink) == b"abcd"
    end

    @testset "peek" begin
        stream = NoopStream(IOBuffer(codeunits("こんにちは")))
        @test peek(stream) == 0xe3
        @test peek(stream, Char) == 'こ'
        @test peek(stream, Int32) == -476872221
        close(stream)
    end

end
