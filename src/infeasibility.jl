# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Infeasibility

import ModelAnalyzer
import JuMP
import JuMP.MOI as MOI

include("intervals.jl")

"""
    Analyzer() <: ModelAnalyzer.AbstractAnalyzer

The `Analyzer` type is used to perform infeasibility analysis on a JuMP model.

## Example
```julia
julia> data = ModelAnalyzer.analyze(
    Analyzer(),
    model,
    optimizer = nothing,,
)
```

The additional keyword argument `optimizer` is used to specify the optimizer to
use for the IIS resolver.
"""
struct Analyzer <: ModelAnalyzer.AbstractAnalyzer end

"""
    AbstractInfeasibilitylIssue

Abstract type for infeasibility issues found during the analysis of a JuMP
model.
"""
abstract type AbstractInfeasibilitylIssue <: ModelAnalyzer.AbstractIssue end

"""
    InfeasibleBounds{T} <: AbstractInfeasibilitylIssue

The `InfeasibleBounds` issue is identified when a variable has a lower bound
that is greater than its upper bound.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Infeasibility.InfeasibleBounds)
````
"""
struct InfeasibleBounds{T} <: AbstractInfeasibilitylIssue
    variable::JuMP.VariableRef
    lb::T
    ub::T
end

"""
    InfeasibleIntegrality{T} <: AbstractInfeasibilitylIssue

The `InfeasibleIntegrality` issue is identified when a variable has an
integrality constraint (like `MOI.Integer` or `MOI.ZeroOne`) that is not 
consistent with its bounds. That is, the bounds do not allow for any
integer value to be feasible.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Infeasibility.InfeasibleIntegrality
)
```
"""
struct InfeasibleIntegrality{T} <: AbstractInfeasibilitylIssue
    variable::JuMP.VariableRef
    lb::T
    ub::T
    set::Union{MOI.Integer,MOI.ZeroOne}#, MOI.Semicontinuous{T}, MOI.Semiinteger{T}}
end

"""
    InfeasibleConstraintRange{T} <: AbstractInfeasibilitylIssue

The `InfeasibleConstraintRange` issue is identified when a constraint cannot
be satisfied given the variable bounds. This analysis only considers one
constraint at a time and all variable bounds of variables involved in the
constraint.
This issue can only be found is all variable bounds are consistent, that is,
no issues of type `InfeasibleBounds` were found in the first layer of analysis.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Infeasibility.InfeasibleConstraintRange
)
```
"""
struct InfeasibleConstraintRange{T} <: AbstractInfeasibilitylIssue
    constraint::JuMP.ConstraintRef
    lb::T
    ub::T
    set::Union{MOI.EqualTo{T},MOI.LessThan{T},MOI.GreaterThan{T}}
end

"""
    IrreducibleInfeasibleSubset <: AbstractInfeasibilitylIssue

The `IrreducibleInfeasibleSubset` issue is identified when a subset of
constraints cannot be satisfied simultaneously. This is typically found
by the IIS resolver after the first two layers of infeasibility analysis
have been completed with no issues, that is, no issues of any other type
were found.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Infeasibility.IrreducibleInfeasibleSubset
)
```
"""
struct IrreducibleInfeasibleSubset <: AbstractInfeasibilitylIssue
    constraint::Vector{JuMP.ConstraintRef}
end

"""
    Data <: ModelAnalyzer.AbstractData

The `Data` type is used to store the results of the infeasibility analysis.
This type contains vectors of the various infeasibility issues found during
the analysis, including `InfeasibleBounds`, `InfeasibleIntegrality`,
`InfeasibleConstraintRange`, and `IrreducibleInfeasibleSubset`.
"""
Base.@kwdef mutable struct Data <: ModelAnalyzer.AbstractData
    infeasible_bounds::Vector{InfeasibleBounds} = InfeasibleBounds[]
    infeasible_integrality::Vector{InfeasibleIntegrality} =
        InfeasibleIntegrality[]

    constraint_range::Vector{InfeasibleConstraintRange} =
        InfeasibleConstraintRange[]

    iis::Vector{IrreducibleInfeasibleSubset} = IrreducibleInfeasibleSubset[]
end

function ModelAnalyzer.analyze(
    ::Analyzer,
    model::JuMP.GenericModel{T};
    optimizer = nothing,
) where {T}
    out = Data()

    variables = Dict{JuMP.VariableRef,Interval{T}}()

    # first layer of infeasibility analysis is bounds consistency
    bounds_consistent = true
    for var in JuMP.all_variables(model)
        lb = if JuMP.has_lower_bound(var)
            JuMP.lower_bound(var)
        elseif JuMP.is_fixed(var)
            JuMP.fix_value(var)
        else
            -Inf
        end
        ub = if JuMP.has_upper_bound(var)
            JuMP.upper_bound(var)
        elseif JuMP.is_fixed(var)
            JuMP.fix_value(var)
        else
            Inf
        end
        if JuMP.is_integer(var)
            if abs(ub - lb) < 1 && ceil(ub) == ceil(lb)
                push!(
                    out.infeasible_integrality,
                    InfeasibleIntegrality(var, lb, ub, MOI.Integer()),
                )
                bounds_consistent = false
            end
        end
        if JuMP.is_binary(var)
            if lb > 0 && ub < 1
                push!(
                    out.infeasible_integrality,
                    InfeasibleIntegrality(var, lb, ub, MOI.ZeroOne()),
                )
                bounds_consistent = false
            end
        end
        if lb > ub
            push!(out.infeasible_bounds, InfeasibleBounds(var, lb, ub))
            bounds_consistent = false
        else
            variables[var] = Interval(lb, ub)
        end
    end
    # check PSD diagonal >= 0 ?
    # other cones?
    if !bounds_consistent
        return out
    end

    # second layer of infeasibility analysis is constraint range analysis
    range_consistent = true
    for (F, S) in JuMP.list_of_constraint_types(model)
        F != JuMP.GenericAffExpr{T,JuMP.VariableRef} && continue
        # TODO: handle quadratics
        !(S in (MOI.EqualTo{T}, MOI.LessThan{T}, MOI.GreaterThan{T})) &&
            continue
        for con in JuMP.all_constraints(model, F, S)
            con_obj = JuMP.constraint_object(con)
            interval = JuMP.value(x -> variables[x], con_obj.func)
            if con_obj.set isa MOI.EqualTo{T}
                rhs = con_obj.set.value
                if interval.lo > rhs || interval.hi < rhs
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange(
                            con,
                            interval.lo,
                            interval.hi,
                            con_obj.set,
                        ),
                    )
                    range_consistent = false
                end
            elseif con_obj.set isa MOI.LessThan{T}
                rhs = con_obj.set.upper
                if interval.lo > rhs
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange(
                            con,
                            interval.lo,
                            interval.hi,
                            con_obj.set,
                        ),
                    )
                    range_consistent = false
                end
            elseif con_obj.set isa MOI.GreaterThan{T}
                rhs = con_obj.set.lower
                if interval.hi < rhs
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange(
                            con,
                            interval.lo,
                            interval.hi,
                            con_obj.set,
                        ),
                    )
                    range_consistent = false
                end
            end
        end
    end

    if !range_consistent
        return out
    end

    # check if there is a optimizer
    # third layer is an IIS resolver
    if optimizer === nothing
        println("iis resolver cannot continue because no optimizer is provided")
        return out
    end
    iis = iis_elastic_filter(model, optimizer)
    # for now, only one iis is computed
    if iis !== nothing
        push!(out.iis, IrreducibleInfeasibleSubset(iis))
    end

    return out
end

function iis_elastic_filter(original_model::JuMP.GenericModel, optimizer)

    # if JuMP.termination_status(original_model) == MOI.OPTIMIZE_NOT_CALLED
    #     println("iis resolver cannot continue because model is not optimized")
    #     # JuMP.optimize!(original_model)
    # end

    status = JuMP.termination_status(original_model)
    if status != MOI.INFEASIBLE
        println(
            "iis resolver cannot continue because model is found to be $(status) by the solver",
        )
        return nothing
    end

    model, reference_map = JuMP.copy_model(original_model)
    JuMP.set_optimizer(model, optimizer)
    JuMP.set_silent(model)
    # TODO handle ".ext" to avoid warning

    constraint_to_affine = JuMP.relax_with_penalty!(model, default = 1.0)
    # might need to do something related to integers / binary

    JuMP.optimize!(model)

    max_iterations = length(constraint_to_affine)

    tolerance = 1e-5

    de_elastisized = []

    for i in 1:max_iterations
        if JuMP.termination_status(model) == MOI.INFEASIBLE
            break
        end
        for (con, func) in constraint_to_affine
            if length(func.terms) == 1
                var = collect(keys(func.terms))[1]
                if JuMP.value(var) > tolerance
                    has_lower = JuMP.has_lower_bound(var)
                    JuMP.fix(var, 0.0; force = true)
                    # or delete(model, var)
                    delete!(constraint_to_affine, con)
                    push!(de_elastisized, (con, var, has_lower))
                end
            elseif length(func.terms) == 2
                var = collect(keys(func.terms))
                coef1 = func.terms[var[1]]
                coef2 = func.terms[var[2]]
                if JuMP.value(var[1]) > tolerance &&
                   JuMP.value(var[2]) > tolerance
                    error("IIS failed due numerical instability")
                elseif JuMP.value(var[1]) > tolerance
                    has_lower = JuMP.has_lower_bound(var[1])
                    JuMP.fix(var[1], 0.0; force = true)
                    # or delete(model, var[1])
                    delete!(constraint_to_affine, con)
                    constraint_to_affine[con] = coef2 * var[2]
                    push!(de_elastisized, (con, var[1], has_lower))
                elseif JuMP.value(var[2]) > tolerance
                    has_lower = JuMP.has_lower_bound(var[2])
                    JuMP.fix(var[2], 0.0; force = true)
                    # or delete(model, var[2])
                    delete!(constraint_to_affine, con)
                    constraint_to_affine[con] = coef1 * var[1]
                    push!(de_elastisized, (con, var[2], has_lower))
                end
            else
                println(
                    "$con and relaxing function with more than two terms: $func",
                )
            end
            JuMP.optimize!(model)
        end
    end

    # consider deleting all no iis constraints
    # be careful with intervals

    # deletion filter
    cadidates = JuMP.ConstraintRef[]
    for (con, var, has_lower) in de_elastisized
        JuMP.unfix(var)
        if has_lower
            JuMP.set_lower_bound(var, 0.0)
        else
            JuMP.set_upper_bound(var, 0.0)
        end
        JuMP.optimize!(model)
        if JuMP.termination_status(model) in
           (MOI.INFEASIBLE, MOI.ALMOST_INFEASIBLE)
            # this constraint is not in IIS
        elseif JuMP.termination_status(model) in
               (MOI.OPTIMAL, MOI.ALMOST_OPTIMAL)
            push!(cadidates, con)
            JuMP.fix(var, 0.0, force = true)
        else
            error(
                "IIS failed due numerical instability, got status $(JuMP.termination_status(model))",
            )
        end
    end

    pre_iis = Set(cadidates)
    iis = JuMP.ConstraintRef[]
    for con in JuMP.all_constraints(
        original_model,
        include_variable_in_set_constraints = false,
    )
        new_con = reference_map[con]
        if new_con in pre_iis
            push!(iis, con)
        end
    end

    return iis
end

# API

function ModelAnalyzer._summarize(io::IO, ::Type{InfeasibleBounds{T}}) where {T}
    return print(io, "# InfeasibleBounds")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{InfeasibleIntegrality{T}},
) where {T}
    return print(io, "# InfeasibleIntegrality")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{InfeasibleConstraintRange{T}},
) where {T}
    return print(io, "# InfeasibleConstraintRange")
end

function ModelAnalyzer._summarize(io::IO, ::Type{IrreducibleInfeasibleSubset})
    return print(io, "# IrreducibleInfeasibleSubset")
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{InfeasibleBounds{T}},
) where {T}
    return print(
        io,
        """
        # `InfeasibleBounds`

        ## What

        A `InfeasibleBounds` issue is identified when a variable has an
        lower bound that is greater than its upper bound.

        ## Why

        This can be a sign of a mistake in the model formulation. This error
        will lead to infeasibility in the optimization problem. 

        ## How to fix

        Fix one of both of the bounds.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{InfeasibleIntegrality{T}},
) where {T}
    return print(
        io,
        """
        # `InfeasibleIntegrality`

        ## What

        A `InfeasibleIntegrality` issue is identified when a variable has an
        and integrality constraint and the bounds do not allow for any integer
        value to be feasible.

        ## Why

        This can be a sign of a mistake in the model formulation. This error
        will lead to infeasibility in the optimization problem. 

        ## How to fix

        Fix one of both of the bounds or remove the integrality constraint.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{InfeasibleConstraintRange{T}},
) where {T}
    return print(
        io,
        """
        # `InfeasibleConstraintRange`

        ## What

        A `InfeasibleConstraintRange` issue is identified when given the variable bounds
        a constraint cannot be satisfied. This analysis only considers one contraint at
        a time and all variable bounds of variables involved in the constraint.

        ## Why

        This can be a sign of a mistake in the model formulation. This error
        will lead to infeasibility in the optimization problem. 

        ## How to fix

        Fix the bounds of variables or the constraint.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{IrreducibleInfeasibleSubset},
)
    return print(
        io,
        """
        # `IrreducibleInfeasibleSubset`

        ## What

        An `IrreducibleInfeasibleSubset` issue is identified when a subset of constraints
        cannot be satisfied simultaneously. 

        ## Why

        This can be a sign of a mistake in the model formulation. This error
        will lead to infeasibility in the optimization problem. 

        ## How to fix

        Fix the constraints in question.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::InfeasibleBounds{T}) where {T}
    return print(io, _name(issue.variable), " : ", issue.lb, " !<= ", issue.ub)
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::InfeasibleIntegrality{T},
) where {T}
    return print(
        io,
        _name(issue.variable),
        " : [",
        issue.lb,
        "; ",
        issue.ub,
        "], ",
        issue.set,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::InfeasibleConstraintRange{T},
) where {T}
    return print(
        io,
        _name(issue.constraint),
        " : [",
        issue.lb,
        "; ",
        issue.ub,
        "], !in ",
        issue.set,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::IrreducibleInfeasibleSubset)
    return print(io, "IIS: ", join(map(_name, issue.constraint), ", "))
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleBounds{T},
) where {T}
    return print(
        io,
        "Variable: ",
        _name(issue.variable),
        " with lower bound ",
        issue.lb,
        " and upper bound ",
        issue.ub,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleIntegrality{T},
) where {T}
    return print(
        io,
        "Variable: ",
        _name(issue.variable),
        " with lower bound ",
        issue.lb,
        " and upper bound ",
        issue.ub,
        " and integrality constraint: ",
        issue.set,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleConstraintRange{T},
) where {T}
    return print(
        io,
        "Constraint: ",
        _name(issue.constraint),
        " with computed lower bound ",
        issue.lb,
        " and computed upper bound ",
        issue.ub,
        " and set: ",
        issue.set,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::IrreducibleInfeasibleSubset,
)
    return print(
        io,
        "Irreducible Infeasible Subset: ",
        join(map(_name, issue.constraint), ", "),
    )
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{InfeasibleBounds})
    return data.infeasible_bounds
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{InfeasibleIntegrality})
    return data.infeasible_integrality
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{InfeasibleConstraintRange},
)
    return data.constraint_range
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{IrreducibleInfeasibleSubset},
)
    return data.iis
end

function ModelAnalyzer.list_of_issue_types(data::Data)
    ret = Type[]
    for type in (
        InfeasibleBounds,
        InfeasibleIntegrality,
        InfeasibleConstraintRange,
        IrreducibleInfeasibleSubset,
    )
        if !isempty(ModelAnalyzer.list_of_issues(data, type))
            push!(ret, type)
        end
    end
    return ret
end

function ModelAnalyzer.summarize(
    io::IO,
    data::Data;
    verbose = true,
    max_issues = ModelAnalyzer.DEFAULT_MAX_ISSUES,
)
    print(io, "## Infeasibility Analysis\n\n")

    for issue_type in ModelAnalyzer.list_of_issue_types(data)
        issues = ModelAnalyzer.list_of_issues(data, issue_type)
        print(io, "\n\n")
        ModelAnalyzer.summarize(
            io,
            issues,
            verbose = verbose,
            max_issues = max_issues,
        )
    end
    return
end

function Base.show(io::IO, data::Data)
    n = sum(
        length(ModelAnalyzer.list_of_issues(data, T)) for
        T in ModelAnalyzer.list_of_issue_types(data);
        init = 0,
    )
    return print(io, "Infeasibility analysis found $n issues")
end

# printing helpers

function _name(ref)
    name = JuMP.name(ref)
    if !isempty(name)
        return name
    end
    return "$(ref.index)"
end

end # module
