# TODO: Remove this file in the future.
using TranscodingStreams.CodecIdentity
@testset "Identity Codec (deprecated)" begin
    TranscodingStreams.test_roundtrip_transcode(Identity, Identity)
    TranscodingStreams.test_roundtrip_read(IdentityStream, IdentityStream)
    TranscodingStreams.test_roundtrip_write(IdentityStream, IdentityStream)
    TranscodingStreams.test_roundtrip_lines(IdentityStream, IdentityStream)
end
