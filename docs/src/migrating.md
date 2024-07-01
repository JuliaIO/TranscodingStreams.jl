Migration
=========

How to migrate from v0.10 to v0.11
----------------------------------

v0.11 has a few subtle breaking changes to `eof` and `seekend`.

### `Memory(data::ByteData)`

The `Memory(data::ByteData)` constructor was removed.
Use `Memory(pointer(data), sizeof(data))` instead.

### `seekend(stream::TranscodingStream)`

Generic `seekend` for `TranscodingStream` was removed.
If the objective is to discard all remaining data in the stream, use `skip(stream, typemax(Int64))` instead where `typemax(Int64)` is meant to be a large number to exhaust the stream.
Ideally, specific implementations of `TranscodingStream` will implement `seekend` only if efficient means exist to avoid fully processing the stream.
`NoopStream` still supports `seekend`.

The previous behavior of the generic `seekend` was something like 
`(seekstart(stream); seekend(stream.stream); stream)` but this led to
inconsistencies with the position of the stream.

### `eof(stream::TranscodingStream)`

`eof` now throws an error if called on a stream that is closed or in writing mode.
Use `!isreadable(stream) || eof(stream)` if you need to more closely match previous behavior.