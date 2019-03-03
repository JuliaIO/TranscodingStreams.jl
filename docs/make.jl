using Documenter
using TranscodingStreams
using CodecZlib

makedocs(
    sitename="TranscodingStreams.jl",
    modules=[TranscodingStreams],
    pages=["index.md", "examples.md", "reference.md", "devnotes.md"],
    assets=["assets/custom.css"],
)

deploydocs(repo="github.com/bicycle1885/TranscodingStreams.jl.git")
