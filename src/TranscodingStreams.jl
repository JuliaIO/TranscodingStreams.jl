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

function test_roundtrip_read end
function test_roundtrip_write end
function test_roundtrip_transcode end
function test_roundtrip_lines end
function test_roundtrip_fileio end
function test_chunked_read end
function test_chunked_write end

if !isdefined(Base, :get_extension)
    include("../ext/TestExt.jl")
end

end # module
