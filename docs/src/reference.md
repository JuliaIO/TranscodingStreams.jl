Reference
=========

```@meta
CurrentModule = TranscodingStreams
```

TranscodingStream
-----------------

```@docs
TranscodingStream(codec::Codec, stream::IO)
transcode
TranscodingStreams.unsafe_transcode!

TranscodingStreams.transcode!
TranscodingStreams.TOKEN_END
TranscodingStreams.unsafe_read
TranscodingStreams.unread
TranscodingStreams.unsafe_unread
Base.position(stream::TranscodingStream)
```

Statistics
----------

```@docs
TranscodingStreams.Stats
TranscodingStreams.stats
```

Codec
-----

```@docs
TranscodingStreams.Noop
TranscodingStreams.NoopStream
Base.position(::NoopStream)
```

```@docs
TranscodingStreams.Codec
TranscodingStreams.expectedsize
TranscodingStreams.minoutsize
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
