# Test Tools
# ==========

function test_roundtrip_read(encoder, decoder)
    srand(12345)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer(data)
        stream = decoder(encoder(file))
        Base.Test.@test hash(read(stream)) == hash(data)
        close(stream)
    end
end

function test_roundtrip_write(encoder, decoder)
    srand(12345)
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
    srand(12345)
    encoder = encode()
    decoder = decode()
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        Base.Test.@test hash(transcode(decoder, transcode(encoder, data))) == hash(data)
    end
end

function test_roundtrip_lines(encoder, decoder)
    srand(12345)
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
