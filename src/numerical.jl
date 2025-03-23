# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Numerical

import ModelAnalyzer
import JuMP
import LinearAlgebra
import JuMP.MOI as MOI
import Printf

struct Analyzer <: ModelAnalyzer.AbstractAnalyzer end

abstract type AbstractNumericalIssue <: ModelAnalyzer.AbstractIssue end

struct VariableNotInConstraints <: AbstractNumericalIssue
    ref::JuMP.VariableRef
end

struct EmptyConstraint <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
end

struct VariableBoundAsConstraint <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
end

struct DenseConstraint <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    nnz::Int
end

struct SmallMatrixCoefficient <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    variable::JuMP.VariableRef
    coefficient::Float64
end

struct LargeMatrixCoefficient <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    variable::JuMP.VariableRef
    coefficient::Float64
end

struct SmallBoundCoefficient <: AbstractNumericalIssue
    variable::JuMP.VariableRef
    coefficient::Float64
end

struct LargeBoundCoefficient <: AbstractNumericalIssue
    variable::JuMP.VariableRef
    coefficient::Float64
end

struct SmallRHSCoefficient <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    coefficient::Float64
end

struct LargeRHSCoefficient <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    coefficient::Float64
end

struct SmallObjectiveCoefficient <: AbstractNumericalIssue
    variable::JuMP.VariableRef
    coefficient::Float64
end

struct LargeObjectiveCoefficient <: AbstractNumericalIssue
    variable::JuMP.VariableRef
    coefficient::Float64
end

struct SmallObjectiveQuadraticCoefficient <: AbstractNumericalIssue
    variable1::JuMP.VariableRef
    variable2::JuMP.VariableRef
    coefficient::Float64
end

struct LargeObjectiveQuadraticCoefficient <: AbstractNumericalIssue
    variable1::JuMP.VariableRef
    variable2::JuMP.VariableRef
    coefficient::Float64
end

struct NonconvexQuadraticConstraint <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
end

struct SmallMatrixQuadraticCoefficient <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    variable1::JuMP.VariableRef
    variable2::JuMP.VariableRef
    coefficient::Float64
end

struct LargeMatrixQuadraticCoefficient <: AbstractNumericalIssue
    ref::JuMP.ConstraintRef
    variable1::JuMP.VariableRef
    variable2::JuMP.VariableRef
    coefficient::Float64
end

Base.@kwdef mutable struct Data <: ModelAnalyzer.AbstractData
    # analysis configuration
    threshold_dense_fill_in::Float64 = 0.10
    threshold_dense_entries::Int = 1000
    threshold_small::Float64 = 1e-5
    threshold_large::Float64 = 1e+5
    # main numbers
    number_of_variables::Int = 0
    number_of_constraints::Int = 0
    constraint_info::Vector{Tuple{DataType,DataType,Int}} =
        Tuple{DataType,DataType,Int}[]
    # objective_info::Any
    matrix_nnz::Int = 0
    # ranges
    matrix_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    bounds_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    rhs_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    objective_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    # cache data
    variables_in_constraints::Set{JuMP.VariableRef} = Set{JuMP.VariableRef}()
    # variables analysis
    variables_not_in_constraints::Vector{VariableNotInConstraints} =
        VariableNotInConstraints[]
    bounds_small::Vector{SmallBoundCoefficient} = SmallBoundCoefficient[]
    bounds_large::Vector{LargeBoundCoefficient} = LargeBoundCoefficient[]
    # constraints analysis
    empty_rows::Vector{EmptyConstraint} = EmptyConstraint[]
    bound_rows::Vector{VariableBoundAsConstraint} = VariableBoundAsConstraint[]
    dense_rows::Vector{DenseConstraint} = DenseConstraint[]
    matrix_small::Vector{SmallMatrixCoefficient} = SmallMatrixCoefficient[]
    matrix_large::Vector{LargeMatrixCoefficient} = LargeMatrixCoefficient[]
    rhs_small::Vector{SmallRHSCoefficient} = SmallRHSCoefficient[]
    rhs_large::Vector{LargeRHSCoefficient} = LargeRHSCoefficient[]
    # quadratic constraints analysis
    has_quadratic_constraints::Bool = false
    nonconvex_rows::Vector{NonconvexQuadraticConstraint} =
        NonconvexQuadraticConstraint[]
    matrix_quadratic_small::Vector{SmallMatrixQuadraticCoefficient} =
        SmallMatrixQuadraticCoefficient[]
    matrix_quadratic_large::Vector{LargeMatrixQuadraticCoefficient} =
        LargeMatrixQuadraticCoefficient[]
    # cache data
    sense::JuMP.OptimizationSense = JuMP.FEASIBILITY_SENSE
    # objective analysis
    objective_small::Vector{SmallObjectiveCoefficient} =
        SmallObjectiveCoefficient[]
    objective_large::Vector{LargeObjectiveCoefficient} =
        LargeObjectiveCoefficient[]
    # quadratic objective analysis
    has_quadratic_objective::Bool = false
    objective_quadratic_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    matrix_quadratic_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    nonconvex_objective::Bool = false
    objective_quadratic_small::Vector{SmallObjectiveQuadraticCoefficient} =
        SmallObjectiveQuadraticCoefficient[]
    objective_quadratic_large::Vector{LargeObjectiveQuadraticCoefficient} =
        LargeObjectiveQuadraticCoefficient[]
end

function _update_range(range::Vector{Float64}, value::Number)
    range[1] = min(range[1], abs(value))
    range[2] = max(range[2], abs(value))
    return 1
end

function _get_constraint_data(
    data,
    ref::JuMP.ConstraintRef,
    func::JuMP.GenericAffExpr;
    ignore_empty = false,
)
    if length(func.terms) == 1
        if isapprox(first(values(func.terms)), 1.0)
            push!(data.bound_rows, VariableBoundAsConstraint(ref))
            data.matrix_nnz += 1
            return
        end
    end
    nnz = 0
    for (variable, coefficient) in func.terms
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.matrix_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_small,
                SmallMatrixCoefficient(ref, variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_large,
                LargeMatrixCoefficient(ref, variable, coefficient),
            )
        end
        push!(data.variables_in_constraints, variable)
    end
    if nnz == 0
        if !ignore_empty
            push!(data.empty_rows, EmptyConstraint(ref))
        end
        return
    end
    if nnz / data.number_of_variables > data.threshold_dense_fill_in &&
       nnz > data.threshold_dense_entries
        push!(data.dense_rows, DenseConstraint(ref, nnz))
    end
    data.matrix_nnz += nnz
    return
end

function _get_constraint_data(
    data,
    ref::JuMP.ConstraintRef,
    func::JuMP.GenericQuadExpr,
)
    nnz = 0
    for (v, coefficient) in func.terms
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.matrix_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_quadratic_small,
                SmallMatrixQuadraticCoefficient(ref, v.a, v.b, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_quadratic_large,
                LargeMatrixQuadraticCoefficient(ref, v.a, v.b, coefficient),
            )
        end
        push!(data.variables_in_constraints, v.a)
        push!(data.variables_in_constraints, v.b)
    end
    data.has_quadratic_constraints = true
    _get_constraint_data(data, ref, func.aff, ignore_empty = nnz > 0)
    return
end

function _get_variable_data(data, variable, coefficient::Number)
    if !(iszero(coefficient))
        _update_range(data.bounds_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.bounds_small,
                SmallBoundCoefficient(variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.bounds_large,
                LargeBoundCoefficient(variable, coefficient),
            )
        end
    end
    return
end

function _get_objective_data(data, func::JuMP.GenericAffExpr)
    nnz = 0
    for (variable, coefficient) in func.terms
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.objective_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.objective_small,
                SmallObjectiveCoefficient(variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.objective_large,
                LargeObjectiveCoefficient(variable, coefficient),
            )
        end
    end
    return
end

function _get_objective_data(data, func::JuMP.GenericQuadExpr)
    _get_objective_data(data, func.aff)
    nnz = 0
    for (v, coefficient) in func.terms
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.objective_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.objective_quadratic_small,
                SmallObjectiveQuadraticCoefficient(v.a, v.b, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.objective_quadratic_large,
                LargeObjectiveQuadraticCoefficient(v.a, v.b, coefficient),
            )
        end
    end
    data.has_quadratic_objective = true
    if data.sense == JuMP.MAX_SENSE
        data.nonconvex_objective = !_quadratic_vexity(func, -1)
    elseif data.sense == JuMP.MIN_SENSE
        data.nonconvex_objective = !_quadratic_vexity(func, 1)
    end
    return
end

function _quadratic_vexity(func::JuMP.GenericQuadExpr, sign::Int)
    variables = JuMP.OrderedCollections.OrderedSet{JuMP.VariableRef}()
    sizehint!(variables, 2 * length(func.terms))
    for v in keys(func.terms)
        push!(variables, v.a)
        push!(variables, v.b)
    end
    var_map = Dict{JuMP.VariableRef,Int}()
    for (idx, var) in enumerate(variables)
        var_map[var] = idx
    end
    matrix = zeros(length(variables), length(variables))
    for (v, coefficient) in func.terms
        matrix[var_map[v.a], var_map[v.b]] += sign * coefficient / 2
        matrix[var_map[v.b], var_map[v.a]] += sign * coefficient / 2
    end
    ret = LinearAlgebra.cholesky!(
        LinearAlgebra.Symmetric(matrix),
        LinearAlgebra.RowMaximum(),
        check = false,
    )
    return LinearAlgebra.issuccess(ret)
end

function _get_constraint_data(data, func::Vector{JuMP.GenericAffExpr}, set)
    for f in func
        _get_constraint_data(data, ref, f, set)
    end
    return true
end

function _get_constraint_data(data, func::Vector{JuMP.GenericQuadExpr}, set)
    for f in func
        _get_constraint_data(data, ref, f, set)
    end
    return true
end

function _get_constraint_data(data, ref, func::JuMP.GenericAffExpr, set)
    coefficient = func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(data, ref, func::JuMP.GenericQuadExpr, set)
    _get_constraint_data(data, ref, func.aff, set)
    # skip additional checks for quadratics in non-scalar simples sets
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericQuadExpr,
    set::MOI.LessThan,
)
    _get_constraint_data(data, ref, func.aff, set)
    if !_quadratic_vexity(func, 1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericAffExpr,
    set::MOI.LessThan,
)
    coefficient = set.upper - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericQuadExpr,
    set::MOI.GreaterThan,
)
    _get_constraint_data(data, ref, func.aff, set)
    if !_quadratic_vexity(func, -1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericAffExpr,
    set::MOI.GreaterThan,
)
    coefficient = set.lower - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericQuadExpr,
    set::Union{MOI.EqualTo,MOI.Interval},
)
    _get_constraint_data(data, ref, func.aff, set)
    push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericAffExpr,
    set::MOI.EqualTo,
)
    coefficient = set.value - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::JuMP.GenericAffExpr,
    set::MOI.Interval,
)
    coefficient = set.upper - func.constant
    if !(iszero(coefficient))
        _update_range(data.rhs_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
        elseif abs(coefficient) > data.threshold_large
            push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
        end
    end
    coefficient = set.lower - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(data, func::Vector{JuMP.VariableRef})
    for var in func
        push!(data.variables_in_constraints, var)
    end
    return
end

# Default fallback for unsupported constraints.
_update_range(data, func, set) = false

"""
    analyze(model::Model; threshold_dense_fill_in = 0.10, threshold_dense_entries = 1000, threshold_small = 1e-5, threshold_large = 1e+5)

Analyze the coefficients of a JuMP model.

"""
function ModelAnalyzer.analyze(
    ::Analyzer,
    model::JuMP.Model;
    threshold_dense_fill_in::Float64 = 0.10,
    threshold_dense_entries::Int = 1000,
    threshold_small::Float64 = 1e-5,
    threshold_large::Float64 = 1e+5,
)
    data = Data()
    data.threshold_dense_fill_in = threshold_dense_fill_in
    data.threshold_dense_entries = threshold_dense_entries
    data.threshold_small = threshold_small
    data.threshold_large = threshold_large

    # initialize simples data
    data.sense = JuMP.objective_sense(model)
    data.number_of_variables = JuMP.num_variables(model)
    sizehint!(data.variables_in_constraints, data.number_of_variables)
    data.number_of_constraints =
        JuMP.num_constraints(model, count_variable_in_set_constraints = false)
    # objective pass
    _get_objective_data(data, JuMP.objective_function(model))
    # variables pass
    for var in JuMP.all_variables(model)
        if JuMP.has_lower_bound(var)
            _get_variable_data(data, var, JuMP.lower_bound(var))
        end
        if JuMP.has_upper_bound(var)
            _get_variable_data(data, var, JuMP.upper_bound(var))
        end
    end
    # constraints pass
    for (F, S) in JuMP.list_of_constraint_types(model)
        n = JuMP.num_constraints(model, F, S)
        if n > 0
            push!(data.constraint_info, (F, S, n))
        end
        F == JuMP.VariableRef && continue
        if F == Vector{JuMP.VariableRef}
            for con in JuMP.all_constraints(model, F, S)
                con_obj = JuMP.constraint_object(con)
                _get_constraint_data(data, con_obj.func)
            end
            continue
        end
        for con in JuMP.all_constraints(model, F, S)
            con_obj = JuMP.constraint_object(con)
            _get_constraint_data(data, con, con_obj.func)
            _get_constraint_data(data, con, con_obj.func, con_obj.set)
        end
    end
    # second pass on variables after constraint pass
    for var in JuMP.all_variables(model)
        if !(var in data.variables_in_constraints)
            push!(
                data.variables_not_in_constraints,
                VariableNotInConstraints(var),
            )
        end
    end
    sort!(data.dense_rows, by = x -> x.nnz, rev = true)
    sort!(data.matrix_small, by = x -> abs(x.coefficient))
    sort!(data.matrix_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.bounds_small, by = x -> abs(x.coefficient))
    sort!(data.bounds_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.rhs_small, by = x -> abs(x.coefficient))
    sort!(data.rhs_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.matrix_quadratic_small, by = x -> abs(x.coefficient))
    sort!(data.matrix_quadratic_large, by = x -> abs(x.coefficient), rev = true)
    # objective
    sort!(data.objective_small, by = x -> abs(x.coefficient))
    sort!(data.objective_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.objective_quadratic_small, by = x -> abs(x.coefficient))
    sort!(
        data.objective_quadratic_large,
        by = x -> abs(x.coefficient),
        rev = true,
    )
    return data
end

# API

function ModelAnalyzer._summarize(io::IO, ::Type{VariableNotInConstraints})
    return print(io, "# VariableNotInConstraints")
end

function ModelAnalyzer._summarize(io::IO, ::Type{EmptyConstraint})
    return print(io, "# EmptyConstraint")
end

function ModelAnalyzer._summarize(io::IO, ::Type{VariableBoundAsConstraint})
    return print(io, "# VariableBoundAsConstraint")
end

function ModelAnalyzer._summarize(io::IO, ::Type{DenseConstraint})
    return print(io, "# DenseConstraint")
end

function ModelAnalyzer._summarize(io::IO, ::Type{SmallMatrixCoefficient})
    return print(io, "# SmallMatrixCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{LargeMatrixCoefficient})
    return print(io, "# LargeMatrixCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{SmallBoundCoefficient})
    return print(io, "# SmallBoundCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{LargeBoundCoefficient})
    return print(io, "# LargeBoundCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{SmallRHSCoefficient})
    return print(io, "# SmallRHSCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{LargeRHSCoefficient})
    return print(io, "# LargeRHSCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{SmallObjectiveCoefficient})
    return print(io, "# SmallObjectiveCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{LargeObjectiveCoefficient})
    return print(io, "# LargeObjectiveCoefficient")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{SmallObjectiveQuadraticCoefficient},
)
    return print(io, "# SmallObjectiveQuadraticCoefficient")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{LargeObjectiveQuadraticCoefficient},
)
    return print(io, "# LargeObjectiveQuadraticCoefficient")
end

function ModelAnalyzer._summarize(io::IO, ::Type{NonconvexQuadraticConstraint})
    return print(io, "# NonconvexQuadraticConstraint")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{SmallMatrixQuadraticCoefficient},
)
    return print(io, "# SmallMatrixQuadraticCoefficient")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{LargeMatrixQuadraticCoefficient},
)
    return print(io, "# LargeMatrixQuadraticCoefficient")
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{VariableNotInConstraints},
)
    return print(
        io,
        """
        # `VariableNotInConstraints`

        ## What

        A `VariableNotInConstraints` issue is identified when a variable appears
        in no constraints.

        ## Why

        This can be a sign of a mistake in the model formulation. If a variable
        is not used in any constraints, it is not affecting the solution of the
        problem. Moreover, it might be leading to an unbounded problem.

        ## How to fix

        If the variable is not needed, remove it from the model. If the variable
        is needed, check that it is correctly used in the constraints.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{EmptyConstraint})
    return print(
        io,
        """
        ## What

        An `EmptyConstraint` issue is identified when a constraint has no
        coefficients different from zero.

        ## Why

        This can be a sign of a mistake in the model formulation. An empty
        constraint is not affecting the solution of the problem. Moreover, it
        might be leading to an infeasible problem since the \"left-hand-side\"
        of the constraint is always zero.

        ## How to fix

        Remove the empty constraint from the model.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{VariableBoundAsConstraint},
)
    return print(
        io,
        """
        ## What

        A `VariableBoundAsConstraint` issue is identified when a constraint is
        equivalent to a variable bound, that is, the constraint has only one
        non-zero coefficient, and this coefficient is equal to one.

        ## Why

        This can be a sign of a mistake in the model formulation. Variable
        bounds are frequently used by solver in special ways that can lead to
        better performance.

        ## How to fix

        Remove the constraint and use the variable bound directly.

        ## More information

        - https://support.gurobi.com/hc/en-us/community/posts/24066470832529/comments/24183896218385
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{DenseConstraint})
    return print(
        io,
        """
        ## What

        A `DenseConstraint` issue is identified when a constraint has a high
        number of non-zero coefficients.

        ## Why

        Dense constraints can lead to performance issues in the solution
        process. Very few dense constraints might not be a problem.

        ## How to fix

        Check if the constraint can be simplified. A common
        case that can be avoided is when there is an expression
        `e = c1 * x1 + c2 * x2 + ... + cn * xn` where `c1, c2, ..., cn` are
        constants and `x1, x2, ..., xn` are variables, and this expression is
        used in many constraints. In this case, it is better to create a new
        variable `y = e` and use `y` in the constraints.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{SmallMatrixCoefficient},
)
    return print(
        io,
        """
        ## What

        A `SmallMatrixCoefficient` issue is identified when a constraint has a
        coefficient with a small absolute value.

        ## Why

        Small coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{LargeMatrixCoefficient},
)
    return print(
        io,
        """
        ## What

        A `LargeMatrixCoefficient` issue is identified when a constraint has a
        coefficient with a large absolute value.

        ## Why

        Large coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{SmallBoundCoefficient})
    return print(
        io,
        """
        ## What

        A `SmallBoundCoefficient` issue is identified when a variable has a
        bound with a small absolute value.

        ## Why

        Small bounds can lead to numerical instability in the solution process.

        ## How to fix

        Check if the bound is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        bounds can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{LargeBoundCoefficient})
    return print(
        io,
        """
        ## What

        A `LargeBoundCoefficient` issue is identified when a variable has a
        bound with a large absolute value.

        ## Why

        Large bounds can lead to numerical instability in the solution process.

        ## How to fix

        Check if the bound is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        bounds can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{SmallRHSCoefficient})
    return print(
        io,
        """
        ## What

        A `SmallRHSCoefficient` issue is identified when a constraint has a
        right-hand-side with a small absolute value.

        ## Why

        Small right-hand-sides can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the right-hand-side is correct. Check if the units of variables
        and coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        right-hand-sides can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{LargeRHSCoefficient})
    return print(
        io,
        """
        ## What

        A `LargeRHSCoefficient` issue is identified when a constraint has a
        right-hand-side with a large absolute value.

        ## Why

        Large right-hand-sides can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the right-hand-side is correct. Check if the units of variables
        and coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        right-hand-sides can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{SmallObjectiveCoefficient},
)
    return print(
        io,
        """
        ## What

        A `SmallObjectiveCoefficient` issue is identified when the objective
        function has a coefficient with a small absolute value.

        ## Why

        Small coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{LargeObjectiveCoefficient},
)
    return print(
        io,
        """
        ## What

        A `LargeObjectiveCoefficient` issue is identified when the objective
        function has a coefficient with a large absolute value.

        ## Why

        Large coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{SmallObjectiveQuadraticCoefficient},
)
    return print(
        io,
        """
        ## What

        A `SmallObjectiveQuadraticCoefficient` issue is identified when the
        objective function has a quadratic coefficient with a small absolute value.

        ## Why

        Small coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{LargeObjectiveQuadraticCoefficient},
)
    return print(
        io,
        """
        ## What

        A `LargeObjectiveQuadraticCoefficient` issue is identified when the
        objective function has a quadratic coefficient with a large absolute value.

        ## Why

        Large coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{NonconvexQuadraticConstraint},
)
    return print(
        io,
        """
        ## What

        A `NonconvexQuadraticConstraint` issue is identified when a quadratic
        constraint is nonconvex, that is, the quadratic matrix is not positive
        semidefinite.

        ## Why

        Nonconvex constraints are not expected by many solver and can lead to
        wrong solutions or even convergence issues.

        ## How to fix

        Check if the constraint is correct. Coefficient signs might have been
        inverted. This also occurs if user fix a variable to emulate a
        parameter, in this case some solvers will not be able to solve the
        model properly, other tools such as ParametricOptInteface.jl might be
        more suitable than fixing variables.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{SmallMatrixQuadraticCoefficient},
)
    return print(
        io,
        """
        ## What

        A `SmallMatrixQuadraticCoefficient` issue is identified when a quadratic
        constraint has a coefficient with a small absolute value.

        ## Why

        Small coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{LargeMatrixQuadraticCoefficient},
)
    return print(
        io,
        """
        ## What

        A `LargeMatrixQuadraticCoefficient` issue is identified when a quadratic
        constraint has a coefficient with a large absolute value.

        ## Why

        Large coefficients can lead to numerical instability in the solution
        process.

        ## How to fix

        Check if the coefficient is correct. Check if the units of variables and
        coefficients are correct. Check if the number makes is
        reasonable given that solver have tolerances. Sometimes these
        coefficients can be replaced by zeros.

        ## More information

        - https://jump.dev/JuMP.jl/stable/tutorials/getting_started/tolerances/
        """,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::VariableNotInConstraints)
    return print(io, _name(issue.ref))
end

function ModelAnalyzer._summarize(io::IO, issue::EmptyConstraint)
    return print(io, _name(issue.ref))
end

function ModelAnalyzer._summarize(io::IO, issue::VariableBoundAsConstraint)
    return print(io, _name(issue.ref))
end

function ModelAnalyzer._summarize(io::IO, issue::DenseConstraint)
    return print(io, _name(issue.ref), " : ", issue.nnz)
end

function ModelAnalyzer._summarize(io::IO, issue::SmallMatrixCoefficient)
    return print(
        io,
        _name(issue.ref),
        " -- ",
        _name(issue.variable),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::LargeMatrixCoefficient)
    return print(
        io,
        _name(issue.ref),
        " -- ",
        _name(issue.variable),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::SmallBoundCoefficient)
    return print(io, _name(issue.variable), " : ", issue.coefficient)
end

function ModelAnalyzer._summarize(io::IO, issue::LargeBoundCoefficient)
    return print(io, _name(issue.variable), " : ", issue.coefficient)
end

function ModelAnalyzer._summarize(io::IO, issue::SmallRHSCoefficient)
    return print(io, _name(issue.ref), " : ", issue.coefficient)
end

function ModelAnalyzer._summarize(io::IO, issue::LargeRHSCoefficient)
    return print(io, _name(issue.ref), " : ", issue.coefficient)
end

function ModelAnalyzer._summarize(io::IO, issue::SmallObjectiveCoefficient)
    return print(io, _name(issue.variable), " : ", issue.coefficient)
end

function ModelAnalyzer._summarize(io::IO, issue::LargeObjectiveCoefficient)
    return print(io, _name(issue.variable), " : ", issue.coefficient)
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::SmallObjectiveQuadraticCoefficient,
)
    return print(
        io,
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::LargeObjectiveQuadraticCoefficient,
)
    return print(
        io,
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::NonconvexQuadraticConstraint)
    return print(io, _name(issue.ref))
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::SmallMatrixQuadraticCoefficient,
)
    return print(
        io,
        _name(issue.ref),
        " -- ",
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::LargeMatrixQuadraticCoefficient,
)
    return print(
        io,
        _name(issue.ref),
        " -- ",
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::VariableNotInConstraints,
)
    return print(io, "Variable: ", _name(issue.ref))
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::EmptyConstraint)
    return print(io, "Constraint: ", _name(issue.ref))
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::VariableBoundAsConstraint,
)
    return print(io, "Constraint: ", _name(issue.ref))
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::DenseConstraint)
    return print(
        io,
        "Constraint: ",
        _name(issue.ref),
        " with ",
        issue.nnz,
        " non zero coefficients",
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::SmallMatrixCoefficient)
    return print(
        io,
        "(Constraint -- Variable): (",
        _name(issue.ref),
        " -- ",
        _name(issue.variable),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::LargeMatrixCoefficient)
    return print(
        io,
        "(Constraint -- Variable): (",
        _name(issue.ref),
        " -- ",
        _name(issue.variable),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::SmallBoundCoefficient)
    return print(
        io,
        "Variable: ",
        _name(issue.variable),
        " with bound ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::LargeBoundCoefficient)
    return print(
        io,
        "Variable: ",
        _name(issue.variable),
        " with bound ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::SmallRHSCoefficient)
    return print(
        io,
        "Constraint: ",
        _name(issue.ref),
        " with right-hand-side ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::LargeRHSCoefficient)
    return print(
        io,
        "Constraint: ",
        _name(issue.ref),
        " with right-hand-side ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallObjectiveCoefficient,
)
    return print(
        io,
        "Variable: ",
        _name(issue.variable),
        " with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeObjectiveCoefficient,
)
    return print(
        io,
        "Variable: ",
        _name(issue.variable),
        " with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallObjectiveQuadraticCoefficient,
)
    return print(
        io,
        "(Variable -- Variable): (",
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeObjectiveQuadraticCoefficient,
)
    return print(
        io,
        "(Variable -- Variable): (",
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::NonconvexQuadraticConstraint,
)
    return print(io, "Constraint: ", _name(issue.ref))
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallMatrixQuadraticCoefficient,
)
    return print(
        io,
        "(Constraint -- Variable -- Variable): (",
        _name(issue.ref),
        " -- ",
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeMatrixQuadraticCoefficient,
)
    return print(
        io,
        "(Constraint -- Variable -- Variable): (",
        _name(issue.ref),
        " -- ",
        _name(issue.variable1),
        " -- ",
        _name(issue.variable2),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{VariableNotInConstraints},
)
    return data.variables_not_in_constraints
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{EmptyConstraint})
    return data.empty_rows
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{VariableBoundAsConstraint},
)
    return data.bound_rows
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{DenseConstraint})
    return data.dense_rows
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallMatrixCoefficient},
)
    return data.matrix_small
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeMatrixCoefficient},
)
    return data.matrix_large
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{SmallBoundCoefficient})
    return data.bounds_small
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{LargeBoundCoefficient})
    return data.bounds_large
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{SmallRHSCoefficient})
    return data.rhs_small
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{LargeRHSCoefficient})
    return data.rhs_large
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallObjectiveCoefficient},
)
    return data.objective_small
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeObjectiveCoefficient},
)
    return data.objective_large
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallObjectiveQuadraticCoefficient},
)
    return data.objective_quadratic_small
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeObjectiveQuadraticCoefficient},
)
    return data.objective_quadratic_large
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{NonconvexQuadraticConstraint},
)
    return data.nonconvex_rows
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallMatrixQuadraticCoefficient},
)
    return data.matrix_quadratic_small
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeMatrixQuadraticCoefficient},
)
    return data.matrix_quadratic_large
end

function ModelAnalyzer.list_of_issue_types(data::Data)
    ret = Type[]
    for type in (
        VariableNotInConstraints,
        EmptyConstraint,
        VariableBoundAsConstraint,
        DenseConstraint,
        SmallMatrixCoefficient,
        LargeMatrixCoefficient,
        SmallBoundCoefficient,
        LargeBoundCoefficient,
        SmallRHSCoefficient,
        LargeRHSCoefficient,
        SmallObjectiveCoefficient,
        LargeObjectiveCoefficient,
        SmallObjectiveQuadraticCoefficient,
        LargeObjectiveQuadraticCoefficient,
        NonconvexQuadraticConstraint,
        SmallMatrixQuadraticCoefficient,
        LargeMatrixQuadraticCoefficient,
    )
        if !isempty(ModelAnalyzer.list_of_issues(data, type))
            push!(ret, type)
        end
    end
    return ret
end

function summarize_configurations(io::IO, data::Data)
    print(io, "## Configuration\n\n")
    print(io, "  Dense fill-in threshold: ", data.threshold_dense_fill_in, "\n")
    print(io, "  Dense entries threshold: ", data.threshold_dense_entries, "\n")
    print(io, "  Small coefficient threshold: ", data.threshold_small, "\n")
    print(io, "  Large coefficient threshold: ", data.threshold_large, "\n")
    return
end

function summarize_dimensions(io::IO, data::Data)
    print(io, "## Dimensions\n\n")
    print(io, "  Number of variables: ", data.number_of_variables, "\n")
    print(io, "  Number of constraints: ", data.number_of_constraints, "\n")
    print(io, "  Number of nonzeros in matrix: ", data.matrix_nnz, "\n")
    # types
    println(io, "  Constraint types:")
    for (F, S, n) in data.constraint_info
        println(io, "    * ", F, "-", S, ": ", n)
    end
    return
end

function summarize_ranges(io::IO, data::Data)
    print(io, "## Coefficient ranges\n\n")
    print(io, "  Matrix:    ", _stringify_bounds(data.matrix_range), "\n")
    print(io, "  Objective: ", _stringify_bounds(data.objective_range), "\n")
    print(io, "  Bounds:    ", _stringify_bounds(data.bounds_range), "\n")
    print(io, "  RHS:       ", _stringify_bounds(data.rhs_range), "\n")
    if data.has_quadratic_objective
        print(
            io,
            "  Objective quadratic: ",
            _stringify_bounds(data.objective_quadratic_range),
            "\n",
        )
    end
    if data.has_quadratic_constraints
        print(
            io,
            "  Matrix quadratic:    ",
            _stringify_bounds(data.matrix_quadratic_range),
            "\n",
        )
    end
    return
end

function ModelAnalyzer.summarize(
    io::IO,
    data::Data;
    verbose = true,
    max_issues = typemax(Int),
    configurations = true,
    dimensions = true,
    ranges = true,
)
    print(io, "## Numerical Analysis\n\n")
    if configurations
        summarize_configurations(io, data)
        print(io, "\n")
    end
    if dimensions
        summarize_dimensions(io, data)
        print(io, "\n")
    end
    if ranges
        summarize_ranges(io, data)
        print(io, "\n")
    end
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
    return print(io, "Numerical analysis found $n issues")
end

# printing helpers

function _name(ref)
    name = JuMP.name(ref)
    if !isempty(name)
        return name
    end
    return "$(ref.index)"
end

_print_value(x::Real) = Printf.@sprintf("%1.0e", x)

function _stringify_bounds(bounds::Vector{Float64})
    lower = bounds[1] < Inf ? _print_value(bounds[1]) : "0e+00"
    upper = bounds[2] > -Inf ? _print_value(bounds[2]) : "0e+00"
    return string("[", lower, ", ", upper, "]")
end

end
