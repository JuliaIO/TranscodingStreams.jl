using TranscodingStreams
using Random
using Test
using TranscodingStreams:
    TranscodingStreams,
    TranscodingStream,
    test_roundtrip_read,
    test_roundtrip_write,
    test_roundtrip_lines,
    test_roundtrip_transcode,
    test_roundtrip_fileio,
    test_chunked_read,
    test_chunked_write,
    Error

# An insane codec for testing the codec APIs.
struct DoubleFrameEncoder <: TranscodingStreams.Codec 
    opened::Base.RefValue{Bool}
    stopped::Base.RefValue{Bool}
    got_stop_msg::Base.RefValue{Bool}
end

DoubleFrameEncoder() = DoubleFrameEncoder(Ref(false), Ref(false), Ref(false))

function TranscodingStreams.process(
        codec  :: DoubleFrameEncoder,
        input  :: TranscodingStreams.Memory,
        output :: TranscodingStreams.Memory,
        error  :: TranscodingStreams.Error,
    )
    if input.size == 0
        codec.got_stop_msg[] = true
    end

    if output.size < 2
        error[] = ErrorException("requires a minimum of 2 bytes of output space")
        return 0, 0, :error
    elseif codec.stopped[]
        error[] = ErrorException("cannot process after stopped")
        return 0, 0, :error
    elseif codec.got_stop_msg[] && input.size != 0
        error[] = ErrorException("cannot accept more input after getting stop message")
        return 0, 0, :error
    elseif !codec.opened[]
        output[1] = UInt8('[')
        output[2] = UInt8(' ')
        codec.opened[] = true
        return 0, 2, :ok
    elseif codec.got_stop_msg[]
        output[1] = UInt8(' ')
        output[2] = UInt8(']')
        codec.stopped[] = true
        return 0, 2, :end
    else
        i = j = 0
        while i + 1 ≤ lastindex(input) && j + 2 ≤ lastindex(output)
            b = input[i+1]
            i += 1
            output[j+1] = output[j+2] = b
            j += 2
        end
        return i, j, :ok
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
        codec  :: DoubleFrameDecoder,
        input  :: TranscodingStreams.Memory,
        output :: TranscodingStreams.Memory,
        error  :: TranscodingStreams.Error,
    )
    Δin::Int = 0
    Δout::Int = 0

    function do_read(ref)
        iszero(input.size) && error("Expected byte")
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
        else
            error("unexpected state $(oldstate)")
        end

        @label state1
        do_read(codec.a) || return (codec.state[]=1; (Δin, Δout, :ok))
        codec.a[] != UInt8('[') && error("expected [")
        @label state2
        do_read(codec.a) || return (codec.state[]=2; (Δin, Δout, :ok))
        codec.a[] != UInt8(' ') && error("expected space")
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
        return Δin, Δout, :end
    catch e
        e isa ErrorException || rethrow()
        error[] = e
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
    @test transcode(DoubleFrameEncoder, b"") == b"[  ]"
    @test transcode(DoubleFrameEncoder, b"a") == b"[ aa ]"
    @test transcode(DoubleFrameEncoder, b"ab") == b"[ aabb ]"
    @test transcode(DoubleFrameEncoder(), b"") == b"[  ]"
    @test transcode(DoubleFrameEncoder(), b"a") == b"[ aa ]"
    @test transcode(DoubleFrameEncoder(), b"ab") == b"[ aabb ]"

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

    @testset "eof is true after write stops" begin
        sink = IOBuffer()
        stream = TranscodingStream(DoubleFrameDecoder(), sink, stop_on_end=true)
        @test_broken write(stream, "[ yy ]sdfsadfasdfdf") == 4
        @test eof(stream)
        @test_throws EOFError read(stream, UInt8)
        flush(stream)
        @test take!(sink) == b"y"
        close(stream)
    end

    test_roundtrip_read(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_write(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_lines(DoubleFrameEncoderStream, DoubleFrameDecoderStream)
    test_roundtrip_transcode(DoubleFrameEncoder, DoubleFrameDecoder)
    test_roundtrip_fileio(DoubleFrameEncoder, DoubleFrameDecoder)
    test_chunked_read(DoubleFrameEncoder, DoubleFrameDecoder)
    test_chunked_write(DoubleFrameEncoder, DoubleFrameDecoder)
end
