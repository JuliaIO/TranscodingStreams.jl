module TranscodingStreams

export
    TranscodingStream,
    Noop,
    NoopStream

const ByteData = Union{Vector{UInt8},Base.CodeUnits{UInt8}}

include("memory.jl")
include("buffer.jl")
include("error.jl")
include("codec.jl")
include("state.jl")
include("stream.jl")
include("io.jl")
include("noop.jl")
include("transcode.jl")

end # module
