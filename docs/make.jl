using Documenter
using TranscodingStreams

makedocs(
    format=:html,
    sitename="TranscodingStreams.jl",
    modules=[TranscodingStreams],
    pages=["index.md", "examples.md", "reference.md", "devnotes.md"],
    assets=["assets/custom.css"])

deploydocs(
    repo="github.com/bicycle1885/TranscodingStreams.jl.git",
    julia="0.7",
    target="build",
    deps=nothing,
    make=nothing)
