__precompile__()

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
include("identity.jl")
include("noop.jl")
include("transcode.jl")
include("testtools.jl")

end # module
