VERSION < v"0.7.0-beta2.199" && __precompile__()

module TranscodingStreams

export
    TranscodingStream,
    Noop,
    NoopStream

using Compat

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
