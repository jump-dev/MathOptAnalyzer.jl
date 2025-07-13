using Documenter, MathOptAnalyzer, JuMP

makedocs(; sitename = "MathOptAnalyzer.jl documentation")

deploydocs(;
    repo = "github.com/jump-dev/MathOptAnalyzer.jl.git",
    push_preview = true,
)
