# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Infeasibility

import MathOptInterface as MOI
import ModelAnalyzer

include("intervals.jl")
include("_eval_variables.jl")

"""
    Analyzer() <: ModelAnalyzer.AbstractAnalyzer

The `Analyzer` type is used to perform infeasibility analysis on a model.

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

Abstract type for infeasibility issues found during the analysis of a
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
    variable::MOI.VariableIndex
    lb::T
    ub::T
end

ModelAnalyzer.variable(issue::InfeasibleBounds) = issue.variable

ModelAnalyzer.values(issue::InfeasibleBounds) = [issue.lb, issue.ub]

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
    variable::MOI.VariableIndex
    lb::T
    ub::T
    set::Union{MOI.Integer,MOI.ZeroOne}#, MOI.Semicontinuous{T}, MOI.Semiinteger{T}}
end

ModelAnalyzer.variable(issue::InfeasibleIntegrality) = issue.variable

ModelAnalyzer.values(issue::InfeasibleIntegrality) = [issue.lb, issue.ub]

ModelAnalyzer.set(issue::InfeasibleIntegrality) = issue.set

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
    constraint::MOI.ConstraintIndex
    lb::T
    ub::T
    set::Union{MOI.EqualTo{T},MOI.LessThan{T},MOI.GreaterThan{T}}
end

ModelAnalyzer.constraint(issue::InfeasibleConstraintRange) = issue.constraint

ModelAnalyzer.values(issue::InfeasibleConstraintRange) = [issue.lb, issue.ub]

ModelAnalyzer.set(issue::InfeasibleConstraintRange) = issue.set

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
    constraint::Vector{<:MOI.ConstraintIndex}
end

ModelAnalyzer.constraints(issue::IrreducibleInfeasibleSubset) = issue.constraint

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
    model::MOI.ModelLike;
    optimizer = nothing,
)
    out = Data()

    T = Float64

    variables = Dict{MOI.VariableIndex,Interval{T}}()

    variable_indices = MOI.get(model, MOI.ListOfVariableIndices())

    lb = Dict{MOI.VariableIndex,T}()
    ub = Dict{MOI.VariableIndex,T}()

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.EqualTo{T}}(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        lb[func] = set.value
        ub[func] = set.value
    end

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.LessThan{T}}(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        # lb[func] = -Inf
        ub[func] = set.upper
    end

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.GreaterThan{T}}(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        lb[func] = set.lower
        # ub[func] = Inf
    end

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.Interval{T}}(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        lb[func] = set.lower
        ub[func] = set.upper
    end

    # for con in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.SemiContinuous{T}}())
    #     set = MOI.get(model, MOI.ConstraintSet(), con)
    #     func = MOI.get(model, MOI.ConstraintFunction(), con)
    #     lb[func] = 0 # set.lower
    #     ub[func] = set.upper
    # end

    # for con in MOI.get(model, MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.SemiInteger{T}}())
    #     set = MOI.get(model, MOI.ConstraintSet(), con)
    #     func = MOI.get(model, MOI.ConstraintFunction(), con)
    #     lb[func] = 0 #set.lower
    #     ub[func] = set.upper
    # end

    bounds_consistent = true

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.Integer}(),
    )
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        _lb = get(lb, func, -Inf)
        _ub = get(ub, func, Inf)
        if abs(_ub - _lb) < 1 && ceil(_ub) == ceil(_lb)
            push!(
                out.infeasible_integrality,
                InfeasibleIntegrality(func, _lb, _ub, MOI.Integer()),
            )
            bounds_consistent = false
        end
    end

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{MOI.VariableIndex,MOI.ZeroOne}(),
    )
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        _lb = get(lb, func, -Inf)
        _ub = get(ub, func, Inf)
        if _lb > 0 && _ub < 1
            push!(
                out.infeasible_integrality,
                InfeasibleIntegrality(func, _lb, _ub, MOI.ZeroOne()),
            )
            bounds_consistent = false
        end
    end

    for var in variable_indices
        _lb = get(lb, var, -Inf)
        _ub = get(ub, var, Inf)
        if _lb > _ub
            push!(out.infeasible_bounds, InfeasibleBounds(var, _lb, _ub))
            bounds_consistent = false
        else
            variables[var] = Interval(_lb, _ub)
        end
    end

    # check PSD diagonal >= 0 ?
    # other cones?
    if !bounds_consistent
        return out
    end

    # second layer of infeasibility analysis is constraint range analysis
    range_consistent = true

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{T},
            MOI.EqualTo{T},
        }(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        failed = false
        interval = _eval_variables(func) do var_idx
            # this only fails if we allow continuing after bounds issues
            # if !haskey(variables, var_idx)
            #     failed = true
            #     return Interval(-Inf, Inf)
            # end
            return variables[var_idx]
        end
        # if failed
        #     continue
        # end
        rhs = set.value
        if interval.lo > rhs || interval.hi < rhs
            push!(
                out.constraint_range,
                InfeasibleConstraintRange(con, interval.lo, interval.hi, set),
            )
            range_consistent = false
        end
    end

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{T},
            MOI.LessThan{T},
        }(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        failed = false
        interval = _eval_variables(func) do var_idx
            # this only fails if we allow continuing after bounds issues
            # if !haskey(variables, var_idx)
            #     failed = true
            #     return Interval(-Inf, Inf)
            # end
            return variables[var_idx]
        end
        # if failed
        #     continue
        # end
        rhs = set.upper
        if interval.lo > rhs
            push!(
                out.constraint_range,
                InfeasibleConstraintRange(con, interval.lo, interval.hi, set),
            )
            range_consistent = false
        end
    end

    for con in MOI.get(
        model,
        MOI.ListOfConstraintIndices{
            MOI.ScalarAffineFunction{T},
            MOI.GreaterThan{T},
        }(),
    )
        set = MOI.get(model, MOI.ConstraintSet(), con)
        func = MOI.get(model, MOI.ConstraintFunction(), con)
        failed = false
        interval = _eval_variables(func) do var_idx
            # this only fails if we allow continuing after bounds issues
            # if !haskey(variables, var_idx)
            #     failed = true
            #     return Interval(-Inf, Inf)
            # end
            return variables[var_idx]
        end
        # if failed
        #     continue
        # end
        rhs = set.lower
        if interval.hi < rhs
            push!(
                out.constraint_range,
                InfeasibleConstraintRange(con, interval.lo, interval.hi, set),
            )
            range_consistent = false
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

function _fix_to_zero(model, variable::MOI.VariableIndex, ::Type{T}) where {T}
    ub_idx =
        MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{T}}(variable.value)
    lb_idx = MOI.ConstraintIndex{MOI.VariableIndex,MOI.GreaterThan{T}}(
        variable.value,
    )
    has_lower = false
    if MOI.is_valid(model, lb_idx)
        MOI.delete(model, lb_idx)
        has_lower = true
        # MOI.PenaltyRelaxation only creates variables with LB
        # elseif MOI.is_valid(model, ub_idx)
        #     MOI.delete(model, ub_idx)
    else
        error("Variable is not bounded")
    end
    MOI.add_constraint(model, variable, MOI.EqualTo{T}(zero(T)))
    return has_lower
end

function _set_bound_zero(
    model,
    variable::MOI.VariableIndex,
    has_lower::Bool,
    ::Type{T},
) where {T}
    eq_idx =
        MOI.ConstraintIndex{MOI.VariableIndex,MOI.EqualTo{T}}(variable.value)
    @assert MOI.is_valid(model, eq_idx)
    MOI.delete(model, eq_idx)
    if has_lower
        MOI.add_constraint(model, variable, MOI.GreaterThan{T}(zero(T)))
        # MOI.PenaltyRelaxation only creates variables with LB
        # else
        #     MOI.add_constraint(model, variable, MOI.LessThan{T}(zero(T)))
    end
    return
end

function iis_elastic_filter(original_model::MOI.ModelLike, optimizer)
    T = Float64

    # handle optimize not called
    status = MOI.get(original_model, MOI.TerminationStatus())
    if !(
        status in
        (MOI.INFEASIBLE, MOI.ALMOST_INFEASIBLE, MOI.ALMOST_INFEASIBLE)
    )
        println(
            "iis resolver cannot continue because model is found to be $(status) by the solver",
        )
        return nothing
    end

    model = MOI.instantiate(optimizer)
    reference_map = MOI.copy_to(model, original_model)
    MOI.set(model, MOI.Silent(), true)

    obj_sense = MOI.get(model, MOI.ObjectiveSense())
    base_obj_type = MOI.get(model, MOI.ObjectiveFunctionType())
    base_obj_func = MOI.get(model, MOI.ObjectiveFunction{base_obj_type}())

    constraint_to_affine =
        MOI.modify(model, MOI.Utilities.PenaltyRelaxation(default = 1.0))
    # might need to do something related to integers / binary
    relaxed_obj_type = MOI.get(model, MOI.ObjectiveFunctionType())
    relaxed_obj_func = MOI.get(model, MOI.ObjectiveFunction{relaxed_obj_type}())

    pure_relaxed_obj_func = relaxed_obj_func - base_obj_func

    max_iterations = length(constraint_to_affine)

    tolerance = 1e-5

    de_elastisized = []

    changed_obj = false

    for i in 1:max_iterations
        MOI.optimize!(model)
        status = MOI.get(model, MOI.TerminationStatus())
        if status in ( # possibily primal unbounded
            MOI.INFEASIBLE_OR_UNBOUNDED,
            MOI.DUAL_INFEASIBLE,
            MOI.ALMOST_DUAL_INFEASIBLE,
        )
            #try with a pure relaxation objective
            MOI.set(
                model,
                MOI.ObjectiveFunction{relaxed_obj_type}(),
                pure_relaxed_obj_func,
            )
            changed_obj = true
            MOI.optimize!(model)
        end
        if status in
           (MOI.INFEASIBLE, MOI.ALMOST_INFEASIBLE, MOI.ALMOST_INFEASIBLE)
            break
        end
        for (con, func) in constraint_to_affine
            if length(func.terms) == 1
                var = func.terms[1].variable
                value = MOI.get(model, MOI.VariablePrimal(), var)
                if value > tolerance
                    has_lower = _fix_to_zero(model, var, T)
                    delete!(constraint_to_affine, con)
                    push!(de_elastisized, (con, var, has_lower))
                end
            elseif length(func.terms) == 2
                var1 = func.terms[1].variable
                coef1 = func.terms[1].coefficient
                var2 = func.terms[2].variable
                coef2 = func.terms[2].coefficient
                value1 = MOI.get(model, MOI.VariablePrimal(), var1)
                value2 = MOI.get(model, MOI.VariablePrimal(), var2)
                if value1 > tolerance && value2 > tolerance
                    error("IIS failed due numerical instability")
                elseif value1 > tolerance
                    # TODO: coef is alwayas 1.0
                    has_lower = _fix_to_zero(model, var1, T)
                    delete!(constraint_to_affine, con)
                    constraint_to_affine[con] = coef2 * var2
                    push!(de_elastisized, (con, var1, has_lower))
                elseif value2 > tolerance
                    has_lower = _fix_to_zero(model, var2, T)
                    delete!(constraint_to_affine, con)
                    constraint_to_affine[con] = coef1 * var1
                    push!(de_elastisized, (con, var2, has_lower))
                end
            else
                println(
                    "$con and relaxing function with more than two terms: $func",
                )
            end
        end
    end

    if changed_obj
        MOI.set(
            model,
            MOI.ObjectiveFunction{relaxed_obj_type}(),
            relaxed_obj_func,
        )
    end

    # consider deleting all no iis constraints
    # be careful with intervals

    obj_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj_func = MOI.get(model, MOI.ObjectiveFunction{obj_type}())
    obj_sense = MOI.get(model, MOI.ObjectiveSense())

    # deletion filter
    cadidates = MOI.ConstraintIndex[]
    for (con, var, has_lower) in de_elastisized
        _set_bound_zero(model, var, has_lower, T)
        MOI.optimize!(model)
        status = MOI.get(model, MOI.TerminationStatus())
        if status in
           (MOI.INFEASIBLE, MOI.ALMOST_INFEASIBLE, MOI.ALMOST_INFEASIBLE)
            # this constraint is not in IIS
        elseif status in (
            MOI.OPTIMAL,
            MOI.ALMOST_OPTIMAL,
            MOI.LOCALLY_SOLVED,
            MOI.ALMOST_LOCALLY_SOLVED,
        )
            push!(cadidates, con)
            _fix_to_zero(model, var, T)
        elseif status in (
            MOI.INFEASIBLE_OR_UNBOUNDED,
            MOI.DUAL_INFEASIBLE,
            MOI.ALMOST_DUAL_INFEASIBLE, # possibily primal unbounded
        )
            MOI.set(model, MOI.ObjectiveSense(), MOI.FEASIBILITY_SENSE)
            MOI.optimize!(model)
            primal_status = MOI.get(model, MOI.PrimalStatus())
            if primal_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
                # this constraint is not in IIS
                push!(cadidates, con)
                _fix_to_zero(model, var, T)
                MOI.set(model, MOI.ObjectiveSense(), obj_sense)
                MOI.set(model, MOI.ObjectiveFunction{obj_type}(), obj_func)
            else
                error(
                    "IIS failed due numerical instability, got status $status,",
                    "then, for MOI.FEASIBILITY_SENSE objective, got primal status $primal_status",
                )
            end
        else
            error("IIS failed due numerical instability, got status $status")
        end
    end

    pre_iis = Set(cadidates)
    iis = MOI.ConstraintIndex[]
    for (F, S) in MOI.get(original_model, MOI.ListOfConstraintTypesPresent())
        if F == MOI.VariableIndex
            continue
        end
        for con in MOI.get(original_model, MOI.ListOfConstraintIndices{F,S}())
            new_con = reference_map[con]
            if new_con in pre_iis
                push!(iis, con)
            end
        end
    end

    return iis
end

# API

function ModelAnalyzer._summarize(io::IO, ::Type{<:InfeasibleBounds})
    return print(io, "# InfeasibleBounds")
end

function ModelAnalyzer._summarize(io::IO, ::Type{<:InfeasibleIntegrality})
    return print(io, "# InfeasibleIntegrality")
end

function ModelAnalyzer._summarize(io::IO, ::Type{<:InfeasibleConstraintRange})
    return print(io, "# InfeasibleConstraintRange")
end

function ModelAnalyzer._summarize(io::IO, ::Type{<:IrreducibleInfeasibleSubset})
    return print(io, "# IrreducibleInfeasibleSubset")
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{<:InfeasibleBounds})
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
    ::Type{<:InfeasibleIntegrality},
)
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
    ::Type{<:InfeasibleConstraintRange},
)
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
    ::Type{<:IrreducibleInfeasibleSubset},
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

function ModelAnalyzer._summarize(io::IO, issue::InfeasibleBounds, model)
    return print(
        io,
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.lb,
        " !<= ",
        issue.ub,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::InfeasibleIntegrality, model)
    return print(
        io,
        ModelAnalyzer._name(issue.variable, model),
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
    issue::InfeasibleConstraintRange,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.constraint, model),
        " : [",
        issue.lb,
        "; ",
        issue.ub,
        "], !in ",
        issue.set,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::IrreducibleInfeasibleSubset,
    model,
)
    return print(
        io,
        "IIS: ",
        join(map(x -> ModelAnalyzer._name(x, model), issue.constraint), ", "),
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleBounds,
    model,
)
    return print(
        io,
        "Variable: ",
        ModelAnalyzer._name(issue.variable, model),
        " with lower bound ",
        issue.lb,
        " and upper bound ",
        issue.ub,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleIntegrality,
    model,
)
    return print(
        io,
        "Variable: ",
        ModelAnalyzer._name(issue.variable, model),
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
    issue::InfeasibleConstraintRange,
    model,
)
    return print(
        io,
        "Constraint: ",
        ModelAnalyzer._name(issue.constraint, model),
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
    model,
)
    return print(
        io,
        "Irreducible Infeasible Subset: ",
        join(map(x -> ModelAnalyzer._name(x, model), issue.constraint), ", "),
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
    model = nothing,
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
            model = model,
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

end # module
