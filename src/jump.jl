import JuMP

# struct JuMPData{T<:AbstractData} <: ModelAnalyzer.AbstractData
#     data::T
#     model::JuMP.Model
# end

# struct JuMPIssue{T<:AbstractIssue} <: ModelAnalyzer.AbstractIssue
#     issue::T
#     model::JuMP.Model
# end

function ModelAnalyzer.analyze(
    analyzer::T,
    model::JuMP.Model;
    kwargs...,
) where {T<:ModelAnalyzer.AbstractAnalyzer}
    moi_model = JuMP.backend(model)
    result = ModelAnalyzer.analyze(analyzer, moi_model; kwargs...)
    # return JuMPData(result, model)
    return result
end

function ModelAnalyzer._name(ref::MOI.VariableIndex, model::JuMP.Model)
    jump_ref = JuMP.VariableRef(model, ref)
    name = JuMP.name(jump_ref)
    if !isempty(name)
        return name
    end
    return "$jump_ref"
end

function ModelAnalyzer._name(ref::MOI.ConstraintIndex, model::JuMP.Model)
    jump_ref = JuMP.constraint_ref_with_index(model, ref)
    name = JuMP.name(jump_ref)
    if !isempty(name)
        return name
    end
    return "$jump_ref"
end

"""
    variable(issue::ModelAnalyzer.AbstractIssue, model::JuMP.Model)

Return the **JuMP** variable reference associated to a particular issue.
"""
function ModelAnalyzer.variable(
    issue::ModelAnalyzer.AbstractIssue,
    model::JuMP.Model,
)
    ref = ModelAnalyzer.variable(issue)
    return JuMP.VariableRef(model, ref)
end

"""
    variables(issue::ModelAnalyzer.AbstractIssue, model::JuMP.Model)

Return the **JuMP** variable references associated to a particular issue.
"""
function ModelAnalyzer.variables(
    issue::ModelAnalyzer.AbstractIssue,
    model::JuMP.Model,
)
    refs = ModelAnalyzer.variables(issue)
    return JuMP.VariableRef.(model, refs)
end

"""
    constraint(issue::ModelAnalyzer.AbstractIssue, model::JuMP.Model)

Return the **JuMP** constraint reference associated to a particular issue.
"""
function ModelAnalyzer.constraint(
    issue::ModelAnalyzer.AbstractIssue,
    model::JuMP.Model,
)
    ref = ModelAnalyzer.constraint(issue)
    return JuMP.constraint_ref_with_index(model, ref)
end
