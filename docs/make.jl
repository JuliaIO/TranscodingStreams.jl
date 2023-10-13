using Documenter
using TranscodingStreams

makedocs(
    sitename="TranscodingStreams.jl",
    modules=[TranscodingStreams],
    pages=["index.md", "examples.md", "reference.md", "devnotes.md"],
    format=Documenter.HTML(; assets=["assets/custom.css"]),
)

deploydocs(repo="github.com/JuliaIO/TranscodingStreams.jl.git", push_preview=true)
