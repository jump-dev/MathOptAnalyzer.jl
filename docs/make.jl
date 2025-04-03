using Documenter, ModelAnalyzer

makedocs(; sitename = "ModelAnalyzer.jl documentation")

deploydocs(;
    repo = "github.com/jump-dev/ModelAnalyzer.jl.git",
    push_preview = true,
)
