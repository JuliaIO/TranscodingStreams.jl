# Basic Supposition.jl tests to ensure nested streams can be read and written to.

include("../test/codecdoubleframe.jl")
using Supposition: Data, @composed, @check, event!

datas = Data.Vectors(Data.Integers{UInt8}())

# Possible kwargs for TranscodingStream constructor
TS_kwarg = @composed (
    bufsize=Data.Integers(1, 2^10),
    stop_on_end=Data.Booleans(),
    sharedbuf=Data.Booleans(),
) -> (
    if sharedbuf
        # default sharedbuf
        (;bufsize, stop_on_end)
    else
        # sharedbuf = false
        (;bufsize, stop_on_end, sharedbuf)
    end
)

# Possible NoopStream wrapper
noop_wrapper = @composed (
    kw=TS_kwarg,
) -> (function noop_wrapper(io)
    event!("noop", kw)
    NoopStream(io; kw...)
end)

# Possible Encoder Decoder wrapper
dec_enc_wrapper = @composed (
    kw_enc=TS_kwarg,
    kw_dec=TS_kwarg,
) -> (function r_enc_dec_wrapper(io)
    event!("encoder", kw_enc)
    event!("decoder", kw_dec)
    DoubleFrameDecoderStream(DoubleFrameEncoderStream(io; kw_enc...); kw_dec...)
end)
enc_dec_wrapper = @composed (
    kw_enc=TS_kwarg,
    kw_dec=TS_kwarg,
) -> (function w_enc_dec_wrapper(io)
    event!("decoder", kw_dec)
    event!("encoder", kw_enc)
    DoubleFrameEncoderStream(DoubleFrameDecoderStream(io; kw_dec...); kw_enc...)
end)

# Possible deeply nested wrappers
read_wrapper = @composed (
    w = Data.Vectors(noop_wrapper | dec_enc_wrapper; max_size=5)
) -> (function read_wrapper(io)
    event!("wrapping IOBuffer with:", nothing)
    (∘(identity, w...))(io)
end)
write_wrapper = @composed (
    w = Data.Vectors(noop_wrapper | enc_dec_wrapper; max_size=5)
) -> (function write_wrapper(io)
    event!("wrapping IOBuffer with:", nothing)
    (∘(identity, w...))(io)
end)

@check max_examples=100000 function read_data(w=read_wrapper, data=datas)
    stream = w(IOBuffer(data))
    read(stream) == data || return false
    eof(stream)
end
@check max_examples=100000 function read_byte_data(w=read_wrapper, data=datas)
    stream = w(IOBuffer(data))
    for i in 1:length(data)
        read(stream, UInt8) == data[i] || return false
    end
    eof(stream)
end

# flush all nested streams and return final data
function take_all(stream)
    if stream isa Base.GenericIOBuffer
        take!(stream)
    else
        write(stream, TranscodingStreams.TOKEN_END)
        flush(stream)
        take_all(stream.stream)
    end
end

@check max_examples=100000 function write_data(w=write_wrapper, data=datas)
    stream = w(IOBuffer())
    write(stream, data) == length(data) || return false
    take_all(stream) == data
end
@check max_examples=100000 function write_byte_data(w=write_wrapper, data=datas)
    stream = w(IOBuffer())
    for i in 1:length(data)
        write(stream, data[i]) == 1 || return false
    end
    take_all(stream) == data
end