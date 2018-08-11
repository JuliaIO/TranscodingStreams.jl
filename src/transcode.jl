# Transcode
# =========

"""
    transcode(::Type{C}, data::Vector{UInt8})::Vector{UInt8} where C<:Codec

Transcode `data` by applying a codec `C()`.

Note that this method does allocation and deallocation of `C()` in every call,
which is handy but less efficient when transcoding a number of objects.
`transcode(codec, data)` is a recommended method in terms of performance.

Examples
--------

```julia
julia> using CodecZlib

julia> data = b"abracadabra";

julia> compressed = transcode(ZlibCompressor, data);

julia> decompressed = transcode(ZlibDecompressor, compressed);

julia> String(decompressed)
"abracadabra"

```
"""
function Base.transcode(::Type{C}, data::ByteData) where C<:Codec
    codec = C()
    initialize(codec)
    try
        return transcode(codec, data)
    finally
        finalize(codec)
    end
end

"""
    transcode(codec::Codec, data::Vector{UInt8})::Vector{UInt8}

Transcode `data` by applying `codec`.

Note that this method does not initialize or finalize `codec`. This is
efficient when you transcode a number of pieces of data, but you need to call
[`TranscodingStreams.initialize`](@ref) and
[`TranscodingStreams.finalize`](@ref) explicitly.

Examples
--------

```julia
julia> using CodecZlib

julia> data = b"abracadabra";

julia> codec = ZlibCompressor();

julia> TranscodingStreams.initialize(codec)

julia> compressed = transcode(codec, data);

julia> TranscodingStreams.finalize(codec)

julia> codec = ZlibDecompressor();

julia> TranscodingStreams.initialize(codec)

julia> decompressed = transcode(codec, compressed);

julia> TranscodingStreams.finalize(codec)

julia> String(decompressed)
"abracadabra"

```
"""
function Base.transcode(codec::Codec, data::ByteData)
    # Add `minoutsize` because `transcode` will be called at least two times.
    buffer2 = Buffer(
        expectedsize(codec, Memory(data)) + minoutsize(codec, Memory(C_NULL, 0)))
    mark!(buffer2)
    stream = TranscodingStream(codec, devnull, State(Buffer(data), buffer2); initialized=true)
    write(stream, TOKEN_END)
    return takemarked!(buffer2)
end
