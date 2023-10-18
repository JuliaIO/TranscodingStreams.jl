# Transcode
# =========

"""
    transcode(
        ::Type{C},
        data::Union{Vector{UInt8},Base.CodeUnits{UInt8}},
    )::Vector{UInt8} where {C<:Codec}

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
function Base.transcode(::Type{C}, args...) where {C<:Codec}
    codec = C()
    initialize(codec)
    try
        return transcode(codec, args...)
    finally
        finalize(codec)
    end
end

# Disambiguate `Base.transcode(::Type{C}, args...)` above from
# `Base.transcode(T, ::String)` in Julia `Base`
function Base.transcode(codec::Type{C}, src::String) where {C<:Codec}
    return invoke(transcode, Tuple{Any, String}, codec, src)
end

_default_output_buffer(codec, input) = Buffer(
    initial_output_size(
        codec,
        buffermem(input)
    )
)

"""
    transcode(
        codec::Codec,
        data::Union{Vector{UInt8},Base.CodeUnits{UInt8},Buffer},
        [output::Union{Vector{UInt8},Base.CodeUnits{UInt8},Buffer}],
    )::Vector{UInt8}

Transcode `data` by applying `codec`.

If `output` is unspecified, then this method will allocate it.

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

julia> compressed = Vector{UInt8}()

julia> transcode(codec, data, compressed);

julia> TranscodingStreams.finalize(codec)

julia> codec = ZlibDecompressor();

julia> TranscodingStreams.initialize(codec)

julia> decompressed = transcode(codec, compressed);

julia> TranscodingStreams.finalize(codec)

julia> String(decompressed)
"abracadabra"

```
"""
function Base.transcode(
    codec::Codec,
    input::Buffer,
    output::Union{Buffer,Nothing} = nothing,
)
    output = (output === nothing ? _default_output_buffer(codec, input) : initbuffer!(output))
    transcode!(output, codec, input)
end

"""
    transcode!(output::Buffer, codec::Codec, input::Buffer)

Transcode `input` by applying `codec` and storing the results in `output`
with validation of input and output.  Note that this method does not initialize
or finalize `codec`. This is efficient when you transcode a number of
pieces of data, but you need to call [`TranscodingStreams.initialize`](@ref) and
[`TranscodingStreams.finalize`](@ref) explicitly.
"""
function transcode!(
    output::Buffer,
    codec::Codec,
    input::Buffer,
)
    Base.mightalias(input.data, output.data) && error(
        "input and outbut buffers must be independent"
    )
    unsafe_transcode!(output, codec, input)
end

"""
    unsafe_transcode!(output::Buffer, codec::Codec, input::Buffer)

Transcode `input` by applying `codec` and storing the results in `output`
without validation of input or output.  Note that this method does not initialize
or finalize `codec`. This is efficient when you transcode a number of
pieces of data, but you need to call [`TranscodingStreams.initialize`](@ref) and
[`TranscodingStreams.finalize`](@ref) explicitly.
"""
function unsafe_transcode!(
    output::Buffer,
    codec::Codec,
    input::Buffer,
)
    error = Error()
    code = startproc(codec, :write, error)
    if code === :error
        @goto error
    end
    n = minoutsize(codec, buffermem(input))
    @label process
    makemargin!(output, n)
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
    elseif code === :end
        if buffersize(input) > 0
            if startproc(codec, :write, error) === :error
                @goto error
            end
            n = minoutsize(codec, buffermem(input))
            @goto process
        end
        resize!(output.data, output.marginpos - 1)
        return output.data
    else
        n = max(Δout, minoutsize(codec, buffermem(input)))
        @goto process
    end
    @label error
    if !haserror(error)
        set_default_error!(error)
    end
    throw(error[])
end

Base.transcode(codec::Codec, data::Buffer, output::ByteData) =
    transcode(codec, data, Buffer(output))

Base.transcode(codec::Codec, data::ByteData, args...) =
    transcode(codec, Buffer(data), args...)

unsafe_transcode!(codec::Codec, data::Buffer, output::ByteData) =
    unsafe_transcode!(Buffer(output), codec, data)

unsafe_transcode!(codec::Codec, data::ByteData, args...) =
    unsafe_transcode!(codec, Buffer(data), args...)

# Return the initial output buffer size.
function initial_output_size(codec::Codec, input::Memory)
    return max(
        minoutsize(codec, input),
        expectedsize(codec, input),
        8,  # just in case where both minoutsize and expectedsize are foolish
    )
end
