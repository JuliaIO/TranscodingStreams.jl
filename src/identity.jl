# Identity Codec
# ==============

module CodecIdentity

export
    Identity,
    IdentityStream

import TranscodingStreams:
    TranscodingStreams,
    TranscodingStream,
    Memory

"""
    Identity()

Create an identity (no-op) codec.
"""
struct Identity <: TranscodingStreams.Codec end

const IdentityStream{S} = TranscodingStream{Identity,S}

"""
    IdentityStream(stream::IO)

Create an identity (no-op) stream.
"""
function IdentityStream(stream::IO)
    return TranscodingStream(Identity(), stream)
end

function TranscodingStreams.process(::Identity, input::Memory, output::Memory)
    n = Int(min(input.size, output.size))
    unsafe_copy!(output.ptr, input.ptr, n)
    return n, n, ifelse(input.size == 0, :end, :ok)
end

end
