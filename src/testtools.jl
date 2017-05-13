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
        mktemp() do path, file
            stream = encoder(decoder(file))
            write(stream, data)
            close(stream)
            Base.Test.@test hash(read(path)) == hash(data)
        end
    end
end
