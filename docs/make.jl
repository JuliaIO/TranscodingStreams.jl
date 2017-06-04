using Documenter
using TranscodingStreams

makedocs(
    format=:html,
    sitename="TranscodingStreams.jl",
    modules=[TranscodingStreams])

deploydocs(
    repo="github.com/bicycle1885/TranscodingStreams.jl.git",
    julia="0.6",
    target="build",
    deps=nothing,
    make=nothing)
