using TranscodingStreams
using Random
using Test
using TranscodingStreams:
    TranscodingStreams,
    TranscodingStream,
    Error
using TestsForCodecPackages:
    test_roundtrip_read,
    test_roundtrip_write,
    test_roundtrip_transcode,
    test_roundtrip_lines,
    test_roundtrip_seekstart,
    test_roundtrip_fileio,
    test_chunked_read,
    test_chunked_write

# An insane codec for testing the codec APIs.
struct DoubleFrameEncoder <: TranscodingStreams.Codec 
    opened::Base.RefValue{Bool}
    stopped::Base.RefValue{Bool}
    got_stop_msg::Base.RefValue{Bool}
    pledged_in_size::Base.RefValue{Int64}
    in_size_count::Base.RefValue{Int64}
end

DoubleFrameEncoder() = DoubleFrameEncoder(Ref(false), Ref(false), Ref(false), Ref(Int64(-1)), Ref(Int64(0)))

function TranscodingStreams.process(
        codec     :: DoubleFrameEncoder,
        input     :: TranscodingStreams.Memory,
        output    :: TranscodingStreams.Memory,
        error_ref :: TranscodingStreams.Error,
    )
    pledged = codec.pledged_in_size[]
    if input.size == 0
        codec.got_stop_msg[] = true
    end

    if output.size < 2
        error_ref[] = ErrorException("requires a minimum of 2 bytes of output space")
        return 0, 0, :error
    elseif codec.stopped[]
        error_ref[] = ErrorException("cannot process after stopped")
        return 0, 0, :error
    elseif codec.got_stop_msg[] && input.size != 0
        error_ref[] = ErrorException("cannot accept more input after getting stop message")
        return 0, 0, :error
    elseif !codec.opened[]
        output[1] = UInt8('[')
        if pledged ∈ (0:9)
            output[2] = UInt8('0'+pledged)
        else
            output[2] = UInt8(' ')
        end
        codec.opened[] = true
        return 0, 2, :ok
    elseif codec.got_stop_msg[]
        # check in_size_count against pledged
        if pledged ∈ (0:9)
            if pledged > codec.in_size_count[]
                error_ref[] = ErrorException("pledged in size was too big")
                return 0, 0, :error
            end
        end
        output[1] = UInt8(' ')
        output[2] = UInt8(']')
        codec.stopped[] = true
        return 0, 2, :end
    else
        i = j = 0
        # check input.size against pledged
        if pledged ∈ (0:9)
            if input.size > pledged || pledged - input.size < codec.in_size_count[]
                error_ref[] = ErrorException("pledged in size was too small")
                return 0, 0, :error
            end
        end
        while i + 1 ≤ lastindex(input) && j + 2 ≤ lastindex(output)
            b = input[i+1]
            i += 1
            output[j+1] = output[j+2] = b
            j += 2
        end
        codec.in_size_count[] += i
        return i, j, :ok
    end
end

function TranscodingStreams.pledgeinsize(
        codec::DoubleFrameEncoder,
        insize::Int64,
        error::Error,
    )::Symbol
    if codec.opened[]
        error[] = ErrorException("pledgeinsize called after opening")
        return :error
    else
        codec.pledged_in_size[] = insize
        return :ok
    end
end

function TranscodingStreams.expectedsize(
              :: DoubleFrameEncoder,
        input :: TranscodingStreams.Memory)
    return input.size * 2 + 2 + 2
end

function TranscodingStreams.minoutsize(
        :: DoubleFrameEncoder,
        :: TranscodingStreams.Memory)
    return 2
end

function TranscodingStreams.startproc(codec::DoubleFrameEncoder, ::Symbol, error::Error)
    codec.opened[] = false
    codec.got_stop_msg[] = false
    codec.stopped[] = false
    codec.pledged_in_size[] = -1
    codec.in_size_count[] = 0
    return :ok
end

# An insane codec for testing the codec APIs.
struct DoubleFrameDecoder <: TranscodingStreams.Codec 
    state::Base.RefValue{Int}
    a::Base.RefValue{UInt8}
    b::Base.RefValue{UInt8}
end

DoubleFrameDecoder() = DoubleFrameDecoder(Ref(1), Ref(0x00), Ref(0x00))

function TranscodingStreams.process(
        codec     :: DoubleFrameDecoder,
        input     :: TranscodingStreams.Memory,
        output    :: TranscodingStreams.Memory,
        error_ref :: TranscodingStreams.Error,
    )
    Δin::Int = 0
    Δout::Int = 0

    function do_read(ref)
        iszero(input.size) && error("expected byte")
        if Δin + 1 ≤ lastindex(input)
            Δin += 1
            ref[] = input[Δin]
            true
        else
            false
        end
    end

    function do_write(x::UInt8)
        if Δout + 1 ≤ lastindex(output)
            Δout += 1
            output[Δout] = x
            true
        else
            false
        end
    end

    try
        # hacky resumable function using goto, just for fun.
        oldstate = codec.state[]
        if oldstate == 1
            @goto state1
        elseif oldstate == 2
            @goto state2
        elseif oldstate == 3
            @goto state3
        elseif oldstate == 4
            @goto state4
        elseif oldstate == 5
            @goto state5
        elseif oldstate == 6
            error("cannot process after ending")
        elseif oldstate == 7
            error("cannot process after erroring")
        else
            error("unexpected state $(oldstate)")
        end

        @label state1
        do_read(codec.a) || return (codec.state[]=1; (Δin, Δout, :ok))
        codec.a[] != UInt8('[') && error("expected [")
        @label state2
        do_read(codec.a) || return (codec.state[]=2; (Δin, Δout, :ok))
        codec.a[] ∉ (UInt8(' '), UInt8('0'):UInt8('9')...) && error("expected space or size")
        while true
            @label state3
            do_read(codec.a) || return (codec.state[]=3; (Δin, Δout, :ok))
            @label state4
            do_read(codec.b) || return (codec.state[]=4; (Δin, Δout, :ok))
            if codec.a[] == codec.b[]
                @label state5
                do_write(codec.a[]) || return (codec.state[]=5; (Δin, Δout, :ok))
            elseif codec.a[] == UInt8(' ') && codec.b[] == UInt8(']')
                break
            else
                error("expected matching bytes or space and ]")
            end
        end
        codec.state[]=6
        return Δin, Δout, :end
    catch e
        codec.state[]=7
        e isa ErrorException || rethrow()
        error_ref[] = e
        return Δin, Δout, :error
    end
end

function TranscodingStreams.startproc(codec::DoubleFrameDecoder, ::Symbol, error::Error)
    codec.state[] = 1
    codec.a[] = 0x00
    codec.b[] = 0x00
    return :ok
end

const DoubleFrameEncoderStream{S} = TranscodingStream{DoubleFrameEncoder,S} where S<:IO
DoubleFrameEncoderStream(stream::IO; kwargs...) = TranscodingStream(DoubleFrameEncoder(), stream; kwargs...)

const DoubleFrameDecoderStream{S} = TranscodingStream{DoubleFrameDecoder,S} where S<:IO
DoubleFrameDecoderStream(stream::IO; kwargs...) = TranscodingStream(DoubleFrameDecoder(), stream; kwargs...)


@testset "DoubleFrame Codecs" begin
    @test transcode(DoubleFrameEncoder, b"") == b"[0 ]"
    @test transcode(DoubleFrameEncoder, b"a") == b"[1aa ]"
    @test transcode(DoubleFrameEncoder, b"ab") == b"[2aabb ]"
    @test transcode(DoubleFrameEncoder(), b"") == b"[0 ]"
    @test transcode(DoubleFrameEncoder(), b"a") == b"[1aa ]"
    @test transcode(DoubleFrameEncoder(), b"ab") == b"[2aabb ]"
    @test transcode(DoubleFrameEncoder(), ones(UInt8,9)) == [b"[9"; ones(UInt8,18); b" ]";]
    @test transcode(DoubleFrameEncoder(), ones(UInt8,10)) == [b"[ "; ones(UInt8,20); b" ]";]

    @test_throws Exception transcode(DoubleFrameDecoder, b"")
    @test_throws Exception transcode(DoubleFrameDecoder, b" [")
    @test_throws Exception transcode(DoubleFrameDecoder, b" ]")
    @test_throws Exception transcode(DoubleFrameDecoder, b"[]")
    @test_throws Exception transcode(DoubleFrameDecoder, b" ")
    @test_throws Exception transcode(DoubleFrameDecoder, b"  ")
    @test_throws Exception transcode(DoubleFrameDecoder, b"aabb")
    @test_throws Exception transcode(DoubleFrameDecoder, b"[ ab ]")
    @test transcode(DoubleFrameDecoder, b"[  ]") == b""
    @test transcode(DoubleFrameDecoder, b"[ aa ]") == b"a"
    @test transcode(DoubleFrameDecoder, b"[ aabb ]") == b"ab"
    @test transcode(DoubleFrameDecoder, b"[ aaaa ]") == b"aa"
    @test transcode(DoubleFrameDecoder, b"[    ]") == b" "
    @test transcode(DoubleFrameDecoder, b"[   ]] ]") == b" ]"
    @test transcode(DoubleFrameDecoder, b"[ aa ][ bb ]") == b"ab"

    @testset "stop_on_end=true prevents underlying stream closing" begin
        sink = IOBuffer()
        stream = TranscodingStream(DoubleFrameDecoder(), sink, stop_on_end=true)
        write(stream, "[ yy ]")
        write(stream, "[ xx ]")
        close(stream)
        @test isopen(sink)
        @test take!(sink) == b"yx"
    end

    @testset "Issue #95" begin
        @test sprint() do outer
            inner = TranscodingStream(DoubleFrameEncoder(), outer, stop_on_end = true)
            println(inner, "Hello, world.")
            close(inner)
        end == "[ HHeelllloo,,  wwoorrlldd..\n\n ]"
    end

    @testset "TOKEN_END repeated doesn't create more empty frames" begin
        sink = IOBuffer()
        stream = TranscodingStream(DoubleFrameEncoder(), sink, stop_on_end=true)
        write(stream, TranscodingStreams.TOKEN_END)
        write(stream, TranscodingStreams.TOKEN_END)
        write(stream, "abc")
        write(stream, TranscodingStreams.TOKEN_END)
        write(stream, "de")
        write(stream, TranscodingStreams.TOKEN_END)
        write(stream, "") # This doesn't create an empty frame
        write(stream, TranscodingStreams.TOKEN_END)
        close(stream)
        @test String(take!(sink)) == "[  ][ aabbcc ][ ddee ]"
    end

    @testset "Issue #160 Safely close stream after failure" begin
        sink = IOBuffer()
        stream = TranscodingStream(DoubleFrameDecoder(), sink)
        write(stream, "abc")
        @test_throws ErrorException("expected [") close(stream)
        @test !isopen(stream)
        @test !isopen(sink)

        @testset "nested decoders" begin
            sink = IOBuffer()
            stream = TranscodingStream(DoubleFrameDecoder(), sink)
            stream2 = TranscodingStream(DoubleFrameDecoder(), stream)
            write(stream2, "abc")
            # "expected byte" error with caused by "expected ["
            @test_throws ErrorException("expected byte") close(stream2)
            @test !isopen(stream2)
            @test !isopen(stream)
            @test !isopen(sink)
        end
    end

    @testset "stop_on_end=true in nested streams" begin
        s1 = DoubleFrameDecoderStream(DoubleFrameEncoderStream(
            DoubleFrameDecoderStream(
                DoubleFrameEncoderStream(IOBuffer(b"")); 
                stop_on_end=true,
            )
        ))
        @test read(s1) == b""
        @test position(s1) == 0
        @test eof(s1)

        s2 = NoopStream(
            DoubleFrameDecoderStream(
                DoubleFrameEncoderStream(IOBuffer(b"")); 
                stop_on_end=true,
            )
        )
        @test read(s2) == b""
        @test position(s1) == 0
        @test eof(s2)
    end

    @testset "reading zero bytes from invalid stream" begin
        # This behavior is required to avoid breaking JLD2.jl
        # `s` must go into read mode, but not actually call `eof`
        for readnone in (io -> read!(io, UInt8[]), io -> read(io, 0), io -> skip(io, 0))
            for invalid_data in (b"", b"asdf")
                s = DoubleFrameDecoderStream(IOBuffer(invalid_data;read=true,write=true))
                @test iswritable(s)
                @test isreadable(s)
                readnone(s)
                @test !iswritable(s)
                @test isreadable(s)
                @test_throws ErrorException eof(s)
            end
        end
    end

    @testset "stats" begin
        @testset "read" begin
            stream = DoubleFrameEncoderStream(IOBuffer(b"foobar"))
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 0
            @test stat.out == 0
            read(stream)
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 6
            @test stat.transcoded_in == 6
            @test stat.transcoded_out == 16
            @test stat.out == 16
            close(stream)

            #nested Streams
            stream = DoubleFrameDecoderStream(DoubleFrameEncoderStream(IOBuffer(b"foobar")))
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 0
            @test stat.out == 0
            read(stream)
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 16
            @test stat.transcoded_in == 16
            @test stat.transcoded_out == 6
            @test stat.out == 6
            close(stream)
        end

        @testset "write" begin
            stream = DoubleFrameEncoderStream(IOBuffer())
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 0
            @test stat.out == 0
            write(stream, b"foobar")
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 6
            @test stat.transcoded_in == 0
            @test stat.transcoded_out == 0
            @test stat.out == 0
            flush(stream)
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 6
            @test stat.transcoded_in == 6
            @test stat.transcoded_out == 14
            @test stat.out == 14
            write(stream, TranscodingStreams.TOKEN_END)
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 6
            @test stat.transcoded_in == 6
            @test stat.transcoded_out == 16
            @test stat.out == 16
            close(stream)

            #nested Streams
            stream = DoubleFrameDecoderStream(DoubleFrameEncoderStream(IOBuffer()))
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 0
            @test stat.out == 0
            write(stream, b"[ ffoooobbaarr ]")
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 16
            @test stat.transcoded_in == 0
            @test stat.transcoded_out == 0
            @test stat.out == 0
            flush(stream)
            stat = TranscodingStreams.stats(stream)
            @test stat.in == 16
            @test stat.transcoded_in == 16
            @test stat.transcoded_out == 6
            @test stat.out == 6
            @test position(stream.stream) == 6
            close(stream)
        end
    end

    @testset "underlying stream fails" begin
        sink = IOBuffer(;maxsize=4)
        stream = DoubleFrameEncoderStream(sink)
        @test write(stream, "abcd") == 4
        # make sure flush doesn't go into an infinite loop
        @test_throws ErrorException("short write") flush(stream)
    end

    @testset "peek" begin
        stream = DoubleFrameDecoderStream(DoubleFrameEncoderStream(IOBuffer(
            codeunits("こんにちは")
        )))
        @test peek(stream) == 0xe3
        @test peek(stream, Char) == 'こ'
        @test peek(stream, Int32) == -476872221
        close(stream)
    end

    @testset "unread" begin
        stream = DoubleFrameDecoderStream(IOBuffer("[ ffoooobbaarr ]"))
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
    end

    test_roundtrip_read(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_write(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_lines(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_seekstart(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_transcode(DoubleFrameEncoder, DoubleFrameDecoder)
    test_roundtrip_fileio(DoubleFrameEncoder, DoubleFrameDecoder)
    test_chunked_read(DoubleFrameEncoder, DoubleFrameDecoder)
    test_chunked_write(DoubleFrameEncoder, DoubleFrameDecoder)
end
