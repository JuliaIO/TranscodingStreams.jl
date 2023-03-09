module TranscodingStreams

export
    TranscodingStream,
    Noop,
    NoopStream

const ByteData = Union{Vector{UInt8},Base.CodeUnits{UInt8}}

# in-place variant of transcode when output buffer size is known
function transcode! end

include("memory.jl")
include("buffer.jl")
include("error.jl")
include("codec.jl")
include("state.jl")
include("stream.jl")
include("io.jl")
include("noop.jl")
include("transcode.jl")
include("testtools.jl")

end # module
