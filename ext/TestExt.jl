module TestExt

using Test: Test
using Random: seed!, randstring

using TranscodingStreams: TranscodingStreams, initialize, finalize, transcode, 
    TranscodingStream, NoopStream, buffersize, TOKEN_END

TEST_RANDOM_SEED = 12345

function TranscodingStreams.test_roundtrip_read(encoder, decoder)
    seed!(TEST_RANDOM_SEED)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer(data)
        stream = decoder(encoder(file))
        Test.@test hash(read(stream)) == hash(data)
        close(stream)
    end
end

function TranscodingStreams.test_roundtrip_write(encoder, decoder)
    seed!(TEST_RANDOM_SEED)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer()
        stream = encoder(decoder(file))
        write(stream, data, TOKEN_END); flush(stream)
        Test.@test hash(take!(file)) == hash(data)
        close(stream)
    end
end

function TranscodingStreams.test_roundtrip_transcode(encode, decode)
    seed!(TEST_RANDOM_SEED)
    encoder = encode()
    initialize(encoder)
    decoder = decode()
    initialize(decoder)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        Test.@test hash(transcode(decode, transcode(encode, data))) == hash(data)
        Test.@test hash(transcode(decoder, transcode(encoder, data))) == hash(data)
    end
    finalize(encoder)
    finalize(decoder)
end

function TranscodingStreams.test_roundtrip_lines(encoder, decoder)
    seed!(TEST_RANDOM_SEED)
    lines = String[]
    buf = IOBuffer()
    stream = encoder(buf)
    for i in 1:100_000
        line = randstring(rand(0:1000))
        println(stream, line)
        push!(lines, line)
    end
    write(stream, TOKEN_END)
    flush(stream)
    seekstart(buf)
    Test.@test hash(lines) == hash(readlines(decoder(buf)))
end

function TranscodingStreams.test_roundtrip_fileio(Encoder, Decoder)
    data = b"""
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla sit amet tempus felis. Etiam molestie urna placerat iaculis pellentesque. Maecenas porttitor et dolor vitae posuere. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc eget nibh quam. Nullam aliquet interdum fringilla. Duis facilisis, lectus in consectetur varius, lorem sem tempor diam, nec auctor tellus nibh sit amet sapien. In ex nunc, elementum eget facilisis ut, luctus eu orci. Sed sapien urna, accumsan et elit non, auctor pretium massa. Phasellus consectetur nisi suscipit blandit aliquam. Nulla facilisi. Mauris pellentesque sem sit amet mi vestibulum eleifend. Nulla faucibus orci ac lorem efficitur, et blandit orci interdum. Aenean posuere ultrices ex sed rhoncus. Donec malesuada mollis sem, sed varius nunc sodales sed. Curabitur lobortis non justo non tristique.
    """
    mktemp() do filename, file
        stream = TranscodingStream(Encoder(), file)
        write(stream, data)
        close(stream)
        stream = TranscodingStream(Decoder(), open(filename))
        Test.@test hash(read(stream)) == hash(data)
        close(stream)
    end
end

function TranscodingStreams.test_chunked_read(Encoder, Decoder)
    seed!(TEST_RANDOM_SEED)
    alpha = b"色即是空"
    encoder = Encoder()
    initialize(encoder)
    for _ in 1:500
        chunks = [rand(alpha, rand(0:100)) for _ in 1:rand(1:100)]
        data = mapfoldl(x->transcode(encoder, x), vcat, chunks, init=UInt8[])
        buffer = NoopStream(IOBuffer(data))
        ok = true
        for chunk in chunks
            stream = TranscodingStream(Decoder(), buffer, stop_on_end=true)
            ok &= hash(read(stream)) == hash(chunk)
            ok &= eof(stream)
            ok &= isreadable(stream)
            close(stream)
        end
        Test.@test ok
    end
    finalize(encoder)
end

function TranscodingStreams.test_chunked_write(Encoder, Decoder)
    seed!(TEST_RANDOM_SEED)
    alpha = b"空即是色"
    encoder = Encoder()
    initialize(encoder)
    for _ in 1:500
        chunks = [rand(alpha, rand(0:100)) for _ in 1:2]
        data = map(x->transcode(encoder, x), chunks)
        buffer = IOBuffer()
        stream = TranscodingStream(Decoder(), buffer, stop_on_end=true)
        write(stream, vcat(data...))
        close(stream)
        ok = true
        ok &= hash(take!(buffer)) == hash(vcat(chunks...))
        ok &= buffersize(stream.state.buffer1) == 0
        Test.@test ok
    end
    finalize(encoder)
end

end # module
