# Identity Codec
# ==============

module CodecIdentity

export
    Identity,
    IdentityStream

using Compat
import TranscodingStreams:
    TranscodingStreams,
    TranscodingStream,
    Memory,
    Error

"""
    Identity()

Create an identity (no-op) codec.
"""
struct Identity <: TranscodingStreams.Codec
    function Identity()
        warn("`Identity` is deprecated, use `Noop` instead", once=true, key=Identity)
        return new()
    end
end

const IdentityStream{S} = TranscodingStream{Identity,S}

"""
    IdentityStream(stream::IO)

Create an identity (no-op) stream.
"""
function IdentityStream(stream::IO)
    warn("`IdentityStream` is deprecated, use `NoopStream` instead", once=true, key=IdentityStream)
    return TranscodingStream(Identity(), stream)
end

function TranscodingStreams.process(::Identity, input::Memory, output::Memory, error::Error)
    n = Int(min(input.size, output.size))
    unsafe_copyto!(output.ptr, input.ptr, n)
    return n, n, ifelse(input.size == 0, :end, :ok)
end

end
