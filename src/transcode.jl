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
    input = Buffer(data)
    output = Buffer(initial_output_size(codec, Memory(data)))
    error = Error()
    code = startproc(codec, :write, error)
    if codec === :error
        @goto error
    end
    while code !== :end || buffersize(input) > 0
        makemargin!(output, minoutsize(codec, buffermem(input)))
        Δin, Δout, code = process(codec, buffermem(input), marginmem(output), error)
        @debug(
            "called process()",
            code = code,
            input_size = buffersize(input),
            output_size = marginsize(output),
            input_delta = Δin,
            output_delta = Δout,
        )
        consumed!(input, Δin)
        supplied!(output, Δout)
        if code === :error
            @goto error
        elseif code === :end && buffersize(input) > 0
            if startproc(codec, :write, error) === :error
                @goto error
            end
        else
            makemargin!(output, Δout)
        end
    end
    if marginsize(output) == 0
        return output.data
    else
        return output.data[1:output.marginpos-1]
    end
    @label error
    if !haserror(error)
        set_default_error!(error)
    end
    throw(error[])
end

# Return the initial output buffer size.
function initial_output_size(codec::Codec, input::Memory)
    return max(
        minoutsize(codec, input),
        expectedsize(codec, input),
        8,  # just in case where both minoutsize and expectedsize are foolish
    )
end
