# Test Tools
# ==========

function test_roundtrip_read(encoder, decoder)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer(data)
        stream = decoder(encoder(file))
        read(stream) == data || error("test failed")
        close(stream)
    end
end

function test_roundtrip_write(encoder, decoder)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        sink = IOBuffer()
        decode_sink = decoder(sink)
        stream = encoder(decode_sink)
        write(stream, data)
        write(stream, TOKEN_END)
        flush(stream)
        write(decode_sink, TOKEN_END)
        flush(decode_sink)
        take!(sink) == data || error("test failed")
        close(stream)
    end
end

function test_roundtrip_transcode(encode, decode)
    encoder = encode()
    initialize(encoder)
    decoder = decode()
    initialize(decoder)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        transcode(decode, transcode(encode, data)) == data || error("test failed")
        transcode(decoder, transcode(encoder, data)) == data || error("test failed")
    end
    finalize(encoder)
    finalize(decoder)
end

function test_roundtrip_lines(encoder, decoder)
    lines = String[]
    buf = IOBuffer()
    stream = encoder(buf)
    for i in 1:100_000
        line = String(rand(UInt8['A':'Z'; 'a':'z'; '0':'9';], rand(0:1000)))
        println(stream, line)
        push!(lines, line)
    end
    write(stream, TOKEN_END)
    flush(stream)
    seekstart(buf)
    lines == readlines(decoder(buf)) || error("test failed")
end

function test_roundtrip_seekstart(encoder, decoder)
    for n in vcat(0:30, sort!(rand(500:100_000, 30))), alpha in (0x00:0xff, 0x00:0x0f)
        data = rand(alpha, n)
        file = IOBuffer(data)
        stream = decoder(encoder(file))
        for m in vcat(0:min(n,20), rand(0:n, 10))
            read(stream, m) == @view(data[1:m]) || error("test failed")
            seekstart(stream)
        end
        seekstart(stream)
        read(stream) == data || error("test failed")
        seekstart(stream)
        read(stream) == data || error("test failed")
        close(stream)
    end
end

function test_roundtrip_fileio(Encoder, Decoder)
    data = b"""
    Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla sit amet tempus felis. Etiam molestie urna placerat iaculis pellentesque. Maecenas porttitor et dolor vitae posuere. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc eget nibh quam. Nullam aliquet interdum fringilla. Duis facilisis, lectus in consectetur varius, lorem sem tempor diam, nec auctor tellus nibh sit amet sapien. In ex nunc, elementum eget facilisis ut, luctus eu orci. Sed sapien urna, accumsan et elit non, auctor pretium massa. Phasellus consectetur nisi suscipit blandit aliquam. Nulla facilisi. Mauris pellentesque sem sit amet mi vestibulum eleifend. Nulla faucibus orci ac lorem efficitur, et blandit orci interdum. Aenean posuere ultrices ex sed rhoncus. Donec malesuada mollis sem, sed varius nunc sodales sed. Curabitur lobortis non justo non tristique.
    """
    mktemp() do filename, file
        stream = TranscodingStream(Encoder(), file)
        write(stream, data)
        close(stream)
        stream = TranscodingStream(Decoder(), open(filename))
        read(stream) == data || error("test failed")
        close(stream)
    end
end

function test_chunked_read(Encoder, Decoder)
    alpha = b"色即是空"
    encoder = Encoder()
    initialize(encoder)
    for sharedbuf in false:true
        for _ in 1:500
            chunks = [rand(alpha, rand(0:100)) for _ in 1:rand(1:100)]
            data = mapfoldl(x->transcode(encoder, x), vcat, chunks, init=UInt8[])
            buffer = NoopStream(IOBuffer(data))
            for chunk in chunks
                stream = TranscodingStream(Decoder(), buffer; stop_on_end=true, sharedbuf)
                read(stream) == chunk || error("test failed")
                position(stream) == length(chunk) || error("test failed")
                eof(stream) || error("test failed")
                isreadable(stream) || error("test failed")
                close(stream)
            end
            # read without stop_on_end should read the full data.
            stream = TranscodingStream(Decoder(), IOBuffer(data))
            read(stream) == reduce(vcat, chunks) || error("test failed")
            close(stream)
        end
    end
    finalize(encoder)
end

function test_chunked_write(Encoder, Decoder)
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
        take!(buffer) == vcat(chunks...) || error("test failed")
    end
    finalize(encoder)
end
