# Codec Interfaces
# ================

"""
An abstract codec type.

Any codec supporting transcoding interfaces must be a subtype of this type.
"""
abstract type Codec end


# Methods
# -------

"""
    initialize(codec::Codec)::Void

Initialize `codec`.
"""
function initialize(codec::Codec)
    return nothing
end

"""
    finalize(codec::Codec)::Void

Finalize `codec`.
"""
function finalize(codec::Codec)::Void
    return nothing
end

"""
    startproc(codec::Codec, state::Symbol)::Symbol

Start data processing with `codec` of `state`.
"""
function startproc(codec::Codec, state::Symbol)::Symbol
    return :ok
end

"""
    process(codec::Codec, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}

Do data processing with `codec`.
"""
function process(codec::Codec, input::Memory, output::Memory)::Tuple{Int,Int,Symbol}
    # no default method
    throw(MethodError(process, (codec, input, output)))
end
