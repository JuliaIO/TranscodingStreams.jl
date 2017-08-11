References
==========

```@meta
CurrentModule = TranscodingStreams
```

TranscodingStream
-----------------

```@docs
TranscodingStream(codec::Codec, stream::IO)
transcode(codec::Codec, data::Vector{UInt8})
TranscodingStreams.TOKEN_END
TranscodingStreams.unsafe_read
```

Codec
-----

```@docs
TranscodingStreams.Noop
TranscodingStreams.NoopStream
```

**This type is deprecated**. Use [`Noop`](@ref) instead.
```@docs
TranscodingStreams.CodecIdentity.Identity
TranscodingStreams.CodecIdentity.IdentityStream
```

```@docs
TranscodingStreams.Codec
TranscodingStreams.initialize
TranscodingStreams.finalize
TranscodingStreams.startproc
TranscodingStreams.process
```

Internal types
--------------

```@docs
TranscodingStreams.Memory
TranscodingStreams.Error
TranscodingStreams.State
```
