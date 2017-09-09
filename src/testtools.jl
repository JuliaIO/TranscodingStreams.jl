# Test Tools
# ==========

TEST_RANDOM_SEED = 12345

function test_roundtrip_read(encoder, decoder)
    srand(TEST_RANDOM_SEED)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer(data)
        stream = decoder(encoder(file))
        Base.Test.@test hash(read(stream)) == hash(data)
        close(stream)
    end
end

function test_roundtrip_write(encoder, decoder)
    srand(TEST_RANDOM_SEED)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer()
        stream = encoder(decoder(file))
        write(stream, data, TOKEN_END); flush(stream)
        Base.Test.@test hash(take!(file)) == hash(data)
        close(stream)
    end
end

function test_roundtrip_transcode(encode, decode)
    srand(TEST_RANDOM_SEED)
    encoder = encode()
    decoder = decode()
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        Base.Test.@test hash(transcode(decode, transcode(encode, data))) == hash(data)
        Base.Test.@test hash(transcode(decoder, transcode(encoder, data))) == hash(data)
    end
    finalize(encoder)
    finalize(decoder)
end

function test_roundtrip_lines(encoder, decoder)
    srand(TEST_RANDOM_SEED)
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
    Base.Test.@test hash(lines) == hash(readlines(decoder(buf)))
end

function test_chunked_read(Encoder, Decoder)
    srand(TEST_RANDOM_SEED)
    alpha = b"色即是空"
    encoder = Encoder()
    initialize(encoder)
    for _ in 1:500
        chunks = [rand(alpha, rand(0:100)) for _ in 1:rand(1:100)]
        data = mapfoldl(x->transcode(encoder, x), vcat, UInt8[], chunks)
        buffer = NoopStream(IOBuffer(data))
        ok = true
        for chunk in chunks
            stream = TranscodingStream(Decoder(), buffer, stop_on_end=true)
            ok &= hash(read(stream)) == hash(chunk)
            ok &= eof(stream)
        end
        Base.Test.@test ok
    end
    finalize(encoder)
end
