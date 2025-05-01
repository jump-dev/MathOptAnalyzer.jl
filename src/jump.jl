using JuMP

# struct JuMPData{T<:AbstractData} <: AbstractData
#     data::T
# end

struct JuMPIssue{T<:AbstractIssue} <: AbstractIssue
    issue::T
end

function analyze(
    analyzer::T,
    model::JuMP.Model;
    kwargs...,
) where {T<:AbstractAnalyzer}
    moi_model = JuMP.backend(model)
    # Perform the analysis
    result = analyze(analyzer, moi_model; kwargs...)
    # return JuMPData(result)
    return result
end

# function _name(ref)
#     name = JuMP.name(ref)
#     if !isempty(name)
#         return name
#     end
#     return "$(ref.index)"
# end
