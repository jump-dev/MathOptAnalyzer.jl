# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module MathOptAnalyzerJuMPExt

import JuMP
import MathOptInterface as MOI
import MathOptAnalyzer

function MathOptAnalyzer.analyze(
    analyzer::MathOptAnalyzer.AbstractAnalyzer,
    model::JuMP.GenericModel;
    kwargs...,
)
    moi_model = JuMP.backend(model)
    result = MathOptAnalyzer.analyze(analyzer, moi_model; kwargs...)
    return result
end

function MathOptAnalyzer._name(
    ref::MOI.VariableIndex,
    model::JuMP.GenericModel{T},
) where {T}
    jump_ref = JuMP.GenericVariableRef{T}(model, ref)
    name = JuMP.name(jump_ref)
    if !isempty(name)
        return name
    end
    return "$jump_ref"
end

function MathOptAnalyzer._name(
    ref::MOI.ConstraintIndex,
    model::JuMP.GenericModel,
)
    jump_ref = JuMP.constraint_ref_with_index(model, ref)
    name = JuMP.name(jump_ref)
    if !isempty(name)
        return name
    end
    return "$jump_ref"
end

function MathOptAnalyzer._show(
    ref::MOI.ConstraintIndex,
    model::JuMP.GenericModel,
)
    jump_ref = JuMP.constraint_ref_with_index(model, ref)
    io = IOBuffer()
    show(io, jump_ref)
    return String(take!(io))
end

"""
    variable(issue::MathOptAnalyzer.AbstractIssue, model::JuMP.GenericModel)

Return the **JuMP** variable reference associated to a particular issue.
"""
function MathOptAnalyzer.variable(
    issue::MathOptAnalyzer.AbstractIssue,
    model::JuMP.GenericModel{T},
) where {T}
    ref = MathOptAnalyzer.variable(issue)
    return JuMP.GenericVariableRef{T}(model, ref)
end

"""
    variables(issue::MathOptAnalyzer.AbstractIssue, model::JuMP.GenericModel)

Return the **JuMP** variable references associated to a particular issue.
"""
function MathOptAnalyzer.variables(
    issue::MathOptAnalyzer.AbstractIssue,
    model::JuMP.GenericModel{T},
) where {T}
    refs = MathOptAnalyzer.variables(issue)
    return JuMP.GenericVariableRef{T}.(model, refs)
end

"""
    constraint(issue::MathOptAnalyzer.AbstractIssue, model::JuMP.GenericModel)

Return the **JuMP** constraint reference associated to a particular issue.
"""
function MathOptAnalyzer.constraint(
    issue::MathOptAnalyzer.AbstractIssue,
    model::JuMP.GenericModel,
)
    ref = MathOptAnalyzer.constraint(issue)
    return JuMP.constraint_ref_with_index(model, ref)
end

"""
    constraintss(issue::MathOptAnalyzer.AbstractIssue, model::JuMP.GenericModel)

Return the **JuMP** constraints reference associated to a particular issue.
"""
function MathOptAnalyzer.constraints(
    issue::MathOptAnalyzer.AbstractIssue,
    model::JuMP.GenericModel,
)
    ref = MathOptAnalyzer.constraints(issue)
    return JuMP.constraint_ref_with_index.(model, ref)
end

end  # module MathOptAnalyzerJuMPExt
