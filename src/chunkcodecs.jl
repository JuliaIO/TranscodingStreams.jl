# Allow a `TranscodingStreams.Codec` to be used as a decoder.

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

# `Codec` subtypes may want to specialize `try_find_decoded_size`
function try_find_decoded_size(::Codec, src::AbstractVector{UInt8})::Nothing
    nothing
end

function try_decode!(codec::Codec, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}; kwargs...)::MaybeSize
    try_resize_decode!(codec, dst, src, Int64(length(dst)))
end

function try_resize_decode!(codec::Codec, dst::AbstractVector{UInt8}, src::AbstractVector{UInt8}, max_size::Int64; kwargs...)::MaybeSize
    dst_size::Int64 = length(dst)
    src_size::Int64 = length(src)
    src_left::Int64 = src_size
    dst_left::Int64 = dst_size
    check_contiguous(dst)
    check_contiguous(src)
    cconv_src = Base.cconvert(Ptr{UInt8}, src)
    err = Error()
    # Outer loop to decode a concatenation of multiple compressed streams.
    while true
        if startproc(codec, :write, err) === :error
            @goto handle_error
        end
        if pledgeinsize(codec, src_left, err) === :error
            @goto handle_error
        end
        # The process loop
        while true
            GC.@preserve cconv_src begin
                local src_p = Base.unsafe_convert(Ptr{UInt8}, cconv_src) + (src_size - src_left)
                local input = Memory(src_p, src_left)
                # ensure minoutsize is provided
                local dst_space_needed = minoutsize(codec, input)
                while dst_space_needed > dst_left
                    local next_size = grow_dst!(dst, max_size)
                    if isnothing(next_size)
                        break # reached max_size limit
                    end
                    dst_left += next_size - dst_size
                    dst_size = next_size
                    @assert dst_left > 0
                end
                cconv_dst = Base.cconvert(Ptr{UInt8}, dst)
                GC.@preserve cconv_dst begin
                    local dst_p = Base.unsafe_convert(Ptr{UInt8}, cconv_dst) + (dst_size - dst_left)
                    if dst_space_needed > dst_left
                        # Try to do the decoding into a scratch buffer
                        # The scratch buffer should typically be just a few bytes.
                        # This enables handling the `return NOT_SIZE` case
                        # while respecting the `minoutsize` restrictions.
                        local scratch_dst = zeros(UInt8, dst_space_needed)
                        local cconv_scratch_dst = Base.cconvert(Ptr{UInt8}, scratch_dst)
                        GC.@preserve cconv_scratch_dst let
                            local scratch_p = Base.unsafe_convert(Ptr{UInt8}, cconv_scratch_dst)
                            local output = Memory(scratch_p, dst_space_needed)
                            local Δin, Δout, code = process(codec, input, output, err)
                            if code === :error
                                @goto handle_error
                            end
                            local valid_Δout = min(Δout, dst_left)
                            src_left -= Δin
                            unsafe_copyto!(dst_p, scratch_p, valid_Δout)
                            if Δout > dst_left
                                # Ran out of dst space
                                return NOT_SIZE
                            end
                            dst_left -= Δout
                            if code === :end
                                if src_left > 0
                                    break # out of the process loop to decode next stream
                                else
                                    # Done
                                    return dst_size - dst_left
                                end
                            end
                        end
                    else
                        local output = Memory(dst_p, dst_left)
                        local Δin, Δout, code = process(codec, input, output, err)
                        if code === :error
                            @goto handle_error
                        end
                        src_left -= Δin
                        dst_left -= Δout
                        if code === :end
                            if src_left > 0
                                break # out of the process loop to decode next stream
                            else
                                # Done
                                return dst_size - dst_left
                            end
                        end
                    end
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
