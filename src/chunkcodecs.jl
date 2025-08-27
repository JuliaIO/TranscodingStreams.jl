# Allow a `TranscodingStreams.Codec` to be used as a decoder.
# Specific `TranscodingStreams.Codec` types may want to specialize `try_find_decoded_size`

using ChunkCodecCore:
    check_in_range,
    check_contiguous,
    grow_dst!,
    MaybeSize,
    NOT_SIZE
import ChunkCodecCore:
    try_decode!,
    try_resize_decode!,
    try_find_decoded_size

function try_find_decoded_size(::Codec, src::AbstractVector{UInt8})::Nothing
    nothing
end

function try_decode!(d::Codec, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::MaybeSize
    try_resize_decode!(d, dst, src, Int64(length(dst)))
end

function try_resize_decode!(d::Codec, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}, max_size::Int64; kwargs...)::MaybeSize
    dst_size::Int64 = length(dst)
    src_size::Int64 = length(src)
    src_left::Int64 = src_size
    dst_left::Int64 = dst_size
    check_contiguous(dst)
    check_contiguous(src)
    cconv_src = Base.cconvert(Ptr{UInt8}, src)
    err = Error()
    # This outer loop is to decode a concatenation of multiple compressed streams.
    while true
        code = startproc(codec, :write, err)
        if code === :error
            @goto handle_error
        end
        if pledgeinsize(codec, src_left, err) === :error
            @goto handle_error
        end
        # This is the process loop
        while true
            GC.@preserve cconv_src begin
                local src_p = Base.unsafe_convert(Ptr{UInt8}, cconv_src)
                local input = Memory(src_p, src_left)
                # ensure minoutsize is provided
                local dst_space_needed = minoutsize(d, input)
                if dst_space_needed > dst_left
                    local next_size = grow_dst!(dst, max_size)
                    if isnothing(next_size) || 
                        # Uh oh no more room to grow dst
                        # but we don't know if the processing is done.
                        # Allocate some extra output to check.
                        local scratch_dst = zeros(UInt8, dst_space_needed)
                    end
                    dst_left += next_size - dst_size
                    dst_size = next_size
                    @assert dst_left > 0

                end
                # dst may get resized, so cconvert needs to be redone on each iteration.
                cconv_dst = Base.cconvert(Ptr{UInt8}, dst)
                GC.@preserve cconv_dst begin
                    local dst_p = Base.unsafe_convert(Ptr{UInt8}, cconv_dst)
                    local output = Memory(dst_p, dst_left)
                end
            end
        end
    end
    @label handle_error
    if !haserror(err)
        set_default_error!(err)
    end
    throw(err[])
end
