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
function Base.transcode(::Type{C}, data::Vector{UInt8}) where C<:Codec
    codec = C()
    try
        return transcode(codec, data)
    finally
        finalize(codec)
    end
end

"""
    transcode(codec::Codec, data::Vector{UInt8})::Vector{UInt8}

Transcode `data` by applying `codec`.

Note that this method does not deallocation of `codec`, which is efficient but
the caller may need to deallocate `codec`.

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
function Base.transcode(codec::Codec, data::Vector{UInt8})
    # Add `minoutsize` because `transcode` will be called at least two times.
    buffer2 = Buffer(
        expectedsize(codec, Memory(data)) + minoutsize(codec, Memory(C_NULL, 0)))
    mark!(buffer2)
    stream = TranscodingStream(codec, DevNull, State(Buffer(data), buffer2))
    write(stream, TOKEN_END)
    return takemarked!(buffer2)
end
