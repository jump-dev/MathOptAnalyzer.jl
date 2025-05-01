# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Numerical

import ModelAnalyzer
import LinearAlgebra
import Printf
import MathOptInterface as MOI

"""
    Analyzer() <: ModelAnalyzer.AbstractAnalyzer

The `Analyzer` type is used to analyze the coefficients of a model for
numerical issues.

## Example

```julia
julia> data = ModelAnalyzer.analyze(
    ModelAnalyzer.Numerical.Analyzer(),
    model;
    threshold_dense_fill_in = 0.10,
    threshold_dense_entries = 1000,
    threshold_small = 1e-5,
    threshold_large = 1e+5,
)
```

The additional parameters:
- `threshold_dense_fill_in`: The threshold for the fraction of non-zero entries
  in a constraint to be considered dense.
- `threshold_dense_entries`: The minimum number of non-zero entries for a
  constraint to be considered dense.
- `threshold_small`: The threshold for small coefficients in the model.
- `threshold_large`: The threshold for large coefficients in the model.

"""
struct Analyzer <: ModelAnalyzer.AbstractAnalyzer end

"""
    AbstractNumericalIssue <: AbstractNumericalIssue

Abstract type for numerical issues found during the analysis of a model.
"""
abstract type AbstractNumericalIssue <: ModelAnalyzer.AbstractIssue end

"""
    VariableNotInConstraints <: AbstractNumericalIssue

The `VariableNotInConstraints` issue is identified when a variable appears in no
constraints.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.VariableNotInConstraints)
```
"""
struct VariableNotInConstraints <: AbstractNumericalIssue
    ref::MOI.VariableIndex
end
ModelAnalyzer.variable(issue::VariableNotInConstraints, model) = issue.ref

"""
    EmptyConstraint <: AbstractNumericalIssue

The `EmptyConstraint` issue is identified when a constraint has no coefficients
different from zero.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.EmptyConstraint)
```
"""
struct EmptyConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
end
ModelAnalyzer.constraint(issue::EmptyConstraint, model) = issue.ref

"""
    VariableBoundAsConstraint <: AbstractNumericalIssue

The `VariableBoundAsConstraint` issue is identified when a constraint is
equivalent to a variable bound, that is, the constraint has only one non-zero
coefficient, and this coefficient is equal to one.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.VariableBoundAsConstraint)
```
"""
struct VariableBoundAsConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
end
ModelAnalyzer.constraint(issue::VariableBoundAsConstraint, model) = issue.ref

"""
    DenseConstraint <: AbstractNumericalIssue

The `DenseConstraint` issue is identified when a constraint has a fraction of
non-zero entries greater than `threshold_dense_fill_in` and the number of
non-zero entries is greater than `threshold_dense_entries`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.DenseConstraint)
```
"""
struct DenseConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    nnz::Int
end
ModelAnalyzer.constraint(issue::DenseConstraint, model) = issue.ref
ModelAnalyzer.value(issue::DenseConstraint) = issue.nnz

"""
    SmallMatrixCoefficient <: AbstractNumericalIssue

The `SmallMatrixCoefficient` issue is identified when a matrix coefficient in a
constraint is smaller than `threshold_small`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.SmallMatrixCoefficient)
```
"""
struct SmallMatrixCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable::MOI.VariableIndex
    coefficient::Float64
end
ModelAnalyzer.variable(issue::SmallMatrixCoefficient, model) = issue.variable
ModelAnalyzer.constraint(issue::SmallMatrixCoefficient, model) = issue.ref
ModelAnalyzer.value(issue::SmallMatrixCoefficient) = issue.coefficient

"""
    LargeMatrixCoefficient <: AbstractNumericalIssue

The `LargeMatrixCoefficient` issue is identified when a matrix coefficient in a
constraint is larger than `threshold_large`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.LargeMatrixCoefficient)
```
"""
struct LargeMatrixCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable::MOI.VariableIndex
    coefficient::Float64
end
ModelAnalyzer.variable(issue::LargeMatrixCoefficient, model) = issue.variable
ModelAnalyzer.constraint(issue::LargeMatrixCoefficient, model) = issue.ref
ModelAnalyzer.value(issue::LargeMatrixCoefficient) = issue.coefficient

"""
    SmallBoundCoefficient <: AbstractNumericalIssue

The `SmallBoundCoefficient` issue is identified when a variable's bound
(coefficient) is smaller than `threshold_small`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.SmallBoundCoefficient)
```
"""
struct SmallBoundCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end
ModelAnalyzer.variable(issue::SmallBoundCoefficient, model) = issue.variable
ModelAnalyzer.value(issue::SmallBoundCoefficient) = issue.coefficient

"""
    LargeBoundCoefficient <: AbstractNumericalIssue

The `LargeBoundCoefficient` issue is identified when a variable's bound
(coefficient) is larger than `threshold_large`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.LargeBoundCoefficient)
```
"""
struct LargeBoundCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end
ModelAnalyzer.variable(issue::LargeBoundCoefficient, model) = issue.variable
ModelAnalyzer.value(issue::LargeBoundCoefficient) = issue.coefficient

"""
    SmallRHSCoefficient <: AbstractNumericalIssue

The `SmallRHSCoefficient` issue is identified when the right-hand-side (RHS)
coefficient of a constraint is smaller than `threshold_small`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.SmallRHSCoefficient)
```
"""
struct SmallRHSCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    coefficient::Float64
end
ModelAnalyzer.constraint(issue::SmallRHSCoefficient, model) = issue.ref
ModelAnalyzer.value(issue::SmallRHSCoefficient) = issue.coefficient

"""
    LargeRHSCoefficient <: AbstractNumericalIssue

The `LargeRHSCoefficient` issue is identified when the right-hand-side (RHS)
coefficient of a constraint is larger than `threshold_large`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.LargeRHSCoefficient)
```
"""
struct LargeRHSCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    coefficient::Float64
end
ModelAnalyzer.constraint(issue::LargeRHSCoefficient, model) = issue.ref
ModelAnalyzer.value(issue::LargeRHSCoefficient) = issue.coefficient

"""
    SmallObjectiveCoefficient <: AbstractNumericalIssue

The `SmallObjectiveCoefficient` issue is identified when a coefficient in the
objective function is smaller than `threshold_small`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.SmallObjectiveCoefficient)
```
"""
struct SmallObjectiveCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end
ModelAnalyzer.variable(issue::SmallObjectiveCoefficient, model) = issue.variable
ModelAnalyzer.value(issue::SmallObjectiveCoefficient) = issue.coefficient

"""
    LargeObjectiveCoefficient <: AbstractNumericalIssue

The `LargeObjectiveCoefficient` issue is identified when a coefficient in the
objective function is larger than `threshold_large`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Numerical.LargeObjectiveCoefficient)
```
"""
struct LargeObjectiveCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end
ModelAnalyzer.variable(issue::LargeObjectiveCoefficient, model) = issue.variable
ModelAnalyzer.value(issue::LargeObjectiveCoefficient) = issue.coefficient

"""
    SmallObjectiveQuadraticCoefficient <: AbstractNumericalIssue

The `SmallObjectiveQuadraticCoefficient` issue is identified when a quadratic
coefficient in the objective function is smaller than `threshold_small`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient
)
```
"""
struct SmallObjectiveQuadraticCoefficient <: AbstractNumericalIssue
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end
function ModelAnalyzer.variables(
    issue::SmallObjectiveQuadraticCoefficient,
    model,
)
    return [issue.variable1, issue.variable2]
end
function ModelAnalyzer.value(issue::SmallObjectiveQuadraticCoefficient)
    return issue.coefficient
end

"""
    LargeObjectiveQuadraticCoefficient <: AbstractNumericalIssue

The `LargeObjectiveQuadraticCoefficient` issue is identified when a quadratic
coefficient in the objective function is larger than `threshold_large`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient
)
```
"""
struct LargeObjectiveQuadraticCoefficient <: AbstractNumericalIssue
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end
function ModelAnalyzer.variables(
    issue::LargeObjectiveQuadraticCoefficient,
    model,
)
    return [issue.variable1, issue.variable2]
end
function ModelAnalyzer.value(issue::LargeObjectiveQuadraticCoefficient)
    return issue.coefficient
end

"""
    SmallMatrixQuadraticCoefficient <: AbstractNumericalIssue

The `SmallMatrixQuadraticCoefficient` issue is identified when a quadratic
coefficient in a constraint is smaller than `threshold_small`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Numerical.SmallMatrixQuadraticCoefficient
)
```
"""
struct SmallMatrixQuadraticCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end
function ModelAnalyzer.variables(issue::SmallMatrixQuadraticCoefficient, model)
    return [issue.variable1, issue.variable2]
end
function ModelAnalyzer.constraint(issue::SmallMatrixQuadraticCoefficient, model)
    return issue.ref
end
ModelAnalyzer.value(issue::SmallMatrixQuadraticCoefficient) = issue.coefficient

"""
    LargeMatrixQuadraticCoefficient <: AbstractNumericalIssue

The `LargeMatrixQuadraticCoefficient` issue is identified when a quadratic
coefficient in a constraint is larger than `threshold_large`.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Numerical.LargeMatrixQuadraticCoefficient
)
```
"""
struct LargeMatrixQuadraticCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end
function ModelAnalyzer.variables(issue::LargeMatrixQuadraticCoefficient, model)
    return [issue.variable1, issue.variable2]
end
function ModelAnalyzer.constraint(issue::LargeMatrixQuadraticCoefficient, model)
    return issue.ref
end
ModelAnalyzer.value(issue::LargeMatrixQuadraticCoefficient) = issue.coefficient

"""
    NonconvexQuadraticObjective <: AbstractNumericalIssue

The `NonconvexQuadraticObjective` issue is identified when a quadratic
objective function is non-convex.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Numerical.NonconvexQuadraticObjective
)
```
"""
struct NonconvexQuadraticObjective <: AbstractNumericalIssue end

"""
    NonconvexQuadraticConstraint

The `NonconvexQuadraticConstraint` issue is identified when a quadratic
constraint is non-convex.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(
    ModelAnalyzer.Numerical.NonconvexQuadraticConstraint
)
```
"""
struct NonconvexQuadraticConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
end
ModelAnalyzer.constraint(issue::NonconvexQuadraticConstraint, model) = issue.ref

"""
    Data

The `Data` structure holds the results of the analysis performed by the
`ModelAnalyzer.Numerical.Analyzer`. It contains various thresholds and the
information about the model's variables, constraints, and objective function.
"""
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
    variables_in_constraints::Set{MOI.VariableIndex} = Set{MOI.VariableIndex}()
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
    sense::MOI.OptimizationSense = MOI.FEASIBILITY_SENSE
    # objective analysis
    objective_small::Vector{SmallObjectiveCoefficient} =
        SmallObjectiveCoefficient[]
    objective_large::Vector{LargeObjectiveCoefficient} =
        LargeObjectiveCoefficient[]
    # quadratic objective analysis
    has_quadratic_objective::Bool = false
    objective_quadratic_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    matrix_quadratic_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    nonconvex_objective::Vector{NonconvexQuadraticObjective} =
        NonconvexQuadraticObjective[]
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

function _get_objective_data(data, func::MOI.VariableIndex)
    return
end

function _get_objective_data(data, func::MOI.ScalarAffineFunction)
    nnz = 0
    for term in func.terms
        variable = term.variable
        coefficient = term.coefficient
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

function _get_objective_data(
    data,
    func::MOI.ScalarQuadraticFunction{T},
) where {T}
    _get_objective_data(
        data,
        MOI.ScalarAffineFunction(func.affine_terms, func.constant),
    )
    nnz = 0
    for term in func.quadratic_terms
        coefficient = term.coefficient
        v1 = term.variable_1
        v2 = term.variable_2
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.objective_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.objective_quadratic_small,
                SmallObjectiveQuadraticCoefficient(v1, v2, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.objective_quadratic_large,
                LargeObjectiveQuadraticCoefficient(v1, v2, coefficient),
            )
        end
    end
    data.has_quadratic_objective = true
    if data.sense == MOI.MAX_SENSE
        if !_quadratic_vexity(func, -1)
            push!(data.nonconvex_objective, NonconvexQuadraticObjective())
        end
    elseif data.sense == MOI.MIN_SENSE
        if !_quadratic_vexity(func, 1)
            push!(data.nonconvex_objective, NonconvexQuadraticObjective())
        end
    end
    return
end

function _quadratic_vexity(func::MOI.ScalarQuadraticFunction, sign::Int)
    variables = Set{MOI.VariableIndex}()
    sizehint!(variables, 2 * length(func.quadratic_terms))
    for term in func.quadratic_terms
        push!(variables, term.variable_1)
        push!(variables, term.variable_2)
    end
    var_map = Dict{MOI.VariableIndex,Int}()
    for (idx, var) in enumerate(variables)
        var_map[var] = idx
    end
    matrix = zeros(length(variables), length(variables))
    for term in func.quadratic_terms
        coefficient = term.coefficient
        v1 = term.variable_1
        v2 = term.variable_2
        matrix[var_map[v1], var_map[v2]] += sign * coefficient / 2
        if v1 != v2
            matrix[var_map[v2], var_map[v1]] += sign * coefficient / 2
        end
    end
    ret = LinearAlgebra.cholesky!(
        LinearAlgebra.Symmetric(matrix),
        LinearAlgebra.RowMaximum(),
        check = false,
    )
    return LinearAlgebra.issuccess(ret)
end

function _quadratic_vexity(func::MOI.VectorQuadraticFunction{T}, sign) where {T}
    n = MOI.output_dimension(func)
    quadratic_terms_vector = [MOI.ScalarQuadraticTerm{T}[] for i in 1:n]
    for term in func.quadratic_terms
        index = term.output_index
        push!(quadratic_terms_vector[index], term.scalar_term)
    end
    for i in 1:n
        if length(quadratic_terms_vector[i]) == 0
            continue
        end
        if !_quadratic_vexity(
            MOI.ScalarQuadraticFunction{T}(
                quadratic_terms_vector[i],
                MOI.ScalarAffineTerm{T}[],
                zero(T),
            ),
            sign,
        )
            return false
        end
    end
    return true
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.ScalarAffineFunction;
    ignore_extras = false,
)
    if length(func.terms) == 1
        coefficient = func.terms[1].coefficient
        if !ignore_extras && isapprox(coefficient, 1.0)
            # TODO: do this in the vector case
            push!(data.bound_rows, VariableBoundAsConstraint(ref))
            data.matrix_nnz += 1
            # in this case we do not count that the variable is in a constraint
            return
        end
    end
    nnz = 0
    for term in func.terms
        variable = term.variable
        coefficient = term.coefficient
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
        if !ignore_extras
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

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.ScalarQuadraticFunction{T},
) where {T}
    nnz = 0
    for term in func.quadratic_terms
        v1 = term.variable_1
        v2 = term.variable_2
        coefficient = term.coefficient
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.matrix_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_quadratic_small,
                SmallMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_quadratic_large,
                LargeMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        end
        push!(data.variables_in_constraints, v1)
        push!(data.variables_in_constraints, v2)
    end
    data.has_quadratic_constraints = true
    _get_constraint_matrix_data(
        data,
        ref,
        MOI.ScalarAffineFunction{T}(func.affine_terms, func.constant),
        ignore_extras = nnz > 0,
    )
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VectorAffineFunction{T},
) where {T}
    for term in func.terms
        variable = term.scalar_term.variable
        coefficient = term.scalar_term.coefficient
        # index = term.output_index
        if iszero(coefficient)
            continue
        end
        _update_range(data.matrix_range, coefficient)
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
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VectorQuadraticFunction{T},
) where {T}
    for term in func.quadratic_terms
        v1 = term.scalar_term.variable_1
        v2 = term.scalar_term.variable_2
        coefficient = term.scalar_term.coefficient
        if iszero(coefficient)
            continue
        end
        _update_range(data.matrix_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_quadratic_small,
                SmallMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_quadratic_large,
                LargeMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        end
        push!(data.variables_in_constraints, v1)
        push!(data.variables_in_constraints, v2)
    end
    _get_constraint_matrix_data(
        data,
        ref,
        MOI.VectorAffineFunction{T}(func.affine_terms, func.constants),
        # ignore_extras = nnz > 0,
    )
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VariableIndex,
)
    # push!(data.variables_in_constraints, func)
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VectorOfVariables,
)
    if length(func.variables) == 1
        return
    end
    for var in func.variables
        push!(data.variables_in_constraints, var)
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::Union{MOI.ScalarAffineFunction,MOI.ScalarQuadraticFunction},
    set,
)
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

function _get_constraint_data(
    data,
    ref,
    func::Union{MOI.VectorAffineFunction,MOI.VectorQuadraticFunction},
    set,
)
    coefficients = func.constants
    for i in eachindex(coefficients)
        coefficient = coefficients[i]
        if iszero(coefficient)
            continue
        end
        _update_range(data.rhs_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
        elseif abs(coefficient) > data.threshold_large
            push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
        end
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarQuadraticFunction{T},
    set::MOI.LessThan{T},
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.ScalarAffineFunction{T}(func.affine_terms, func.constant),
        set,
    )
    if !_quadratic_vexity(func, 1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VectorQuadraticFunction{T},
    set::MOI.Nonpositives,
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.VectorAffineFunction{T}(func.affine_terms, func.constants),
        set,
    )
    if !_quadratic_vexity(func, 1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
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
    func::MOI.ScalarQuadraticFunction{T},
    set::MOI.GreaterThan{T},
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.ScalarAffineFunction{T}(func.affine_terms, func.constant),
        set,
    )
    if !_quadratic_vexity(func, -1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VectorQuadraticFunction{T},
    set::MOI.Nonnegatives,
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.VectorAffineFunction{T}(func.affine_terms, func.constants),
        set,
    )
    if !_quadratic_vexity(func, -1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
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
    func::MOI.ScalarQuadraticFunction,
    set::Union{MOI.EqualTo,MOI.Interval},
)
    _get_constraint_data(
        data,
        ref,
        MOI.ScalarAffineFunction(func.affine_terms, func.constant),
        set,
    )
    push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VectorQuadraticFunction,
    set::MOI.Zeros,
)
    _get_constraint_data(
        data,
        ref,
        MOI.VectorAffineFunction(func.affine_terms, func.constants),
        set,
    )
    push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
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
    func::MOI.ScalarAffineFunction,
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

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.LessThan,
)
    _get_variable_data(data, func, set.upper)
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.GreaterThan,
)
    _get_variable_data(data, func, set.lower)
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.EqualTo,
)
    _get_variable_data(data, func, set.value)
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.Interval,
)
    _get_variable_data(data, func, set.lower)
    _get_variable_data(data, func, set.upper)
    return
end

function _get_constraint_data(data, ref, func::MOI.VariableIndex, set)
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

function _get_constraint_data(data, ref, func::MOI.VectorOfVariables, set)
    return
end

"""
    analyze(model::Model; threshold_dense_fill_in = 0.10, threshold_dense_entries = 1000, threshold_small = 1e-5, threshold_large = 1e+5)

Analyze the coefficients of a model.

"""
function ModelAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike,
    ;
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
    data.sense = MOI.get(model, MOI.ObjectiveSense())
    data.number_of_variables = MOI.get(model, MOI.NumberOfVariables())
    sizehint!(data.variables_in_constraints, data.number_of_variables)

    # objective pass
    objective_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj_func = MOI.get(model, MOI.ObjectiveFunction{objective_type}())
    _get_objective_data(data, obj_func)

    # constraints pass
    data.number_of_constraints = 0
    list_of_constraint_types =
        MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in list_of_constraint_types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        n = length(list)
        data.number_of_constraints += n
        if n > 0
            push!(data.constraint_info, (F, S, n))
        end
        for con in list
            func = MOI.get(model, MOI.ConstraintFunction(), con)
            set = MOI.get(model, MOI.ConstraintSet(), con)
            _get_constraint_matrix_data(data, con, func)
            _get_constraint_data(data, con, func, set)
        end
    end
    # second pass on variables after constraint pass
    # variable index constraints are not counted in the constraints pass
    list_of_variables = MOI.get(model, MOI.ListOfVariableIndices())
    for var in list_of_variables
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

function ModelAnalyzer._summarize(io::IO, ::Type{NonconvexQuadraticObjective})
    return print(io, "# NonconvexQuadraticObjective")
end

function ModelAnalyzer._summarize(io::IO, ::Type{NonconvexQuadraticConstraint})
    return print(io, "# NonconvexQuadraticConstraint")
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
        in no constraints. If a variable only appears alone in a constraint and
        it has a coefficient of 1 it is considered a
        `VariableNotInConstraints`, because this emulates a bound.

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
        # `EmptyConstraint`

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
        # `VariableBoundAsConstraint`

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
        # `DenseConstraint`

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
        # `SmallMatrixCoefficient`

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
        # `LargeMatrixCoefficient`

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
        # `SmallBoundCoefficient`

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
        # `LargeBoundCoefficient`

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
        # `SmallRHSCoefficient`

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
        # `LargeRHSCoefficient`

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
        # `SmallObjectiveCoefficient`

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
        # `LargeObjectiveCoefficient`

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
        # `SmallObjectiveQuadraticCoefficient`

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
        # `LargeObjectiveQuadraticCoefficient`

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
    ::Type{SmallMatrixQuadraticCoefficient},
)
    return print(
        io,
        """
        # `SmallMatrixQuadraticCoefficient`

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
    ::Type{NonconvexQuadraticObjective},
)
    return print(
        io,
        """
        # `NonconvexQuadraticObjective`

        ## What

        A `NonconvexQuadraticObjective` issue is identified when a quadratic
        objective is nonconvex, that is, the quadratic matrix is not positive
        semidefinite for minimization or the quadratic matrix is not negative
        semidefinite for maximization.

        ## Why

        Nonconvex objectives are not expected by many solver and can lead to
        wrong solutions or even convergence issues.

        ## How to fix

        Check if the objective is correct. Coefficient signs might have been
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
    ::Type{NonconvexQuadraticConstraint},
)
    return print(
        io,
        """
        # `NonconvexQuadraticConstraint`

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
    ::Type{LargeMatrixQuadraticCoefficient},
)
    return print(
        io,
        """
        # `LargeMatrixQuadraticCoefficient`

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

function ModelAnalyzer._summarize(
    io::IO,
    issue::VariableNotInConstraints,
    model,
)
    return print(io, ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._summarize(io::IO, issue::EmptyConstraint, model)
    return print(io, ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::VariableBoundAsConstraint,
    model,
)
    return print(io, ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._summarize(io::IO, issue::DenseConstraint, model)
    return print(io, ModelAnalyzer._name(issue.ref, model), " : ", issue.nnz)
end

function ModelAnalyzer._summarize(io::IO, issue::SmallMatrixCoefficient, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::LargeMatrixCoefficient, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::SmallBoundCoefficient, model)
    return print(
        io,
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::LargeBoundCoefficient, model)
    return print(
        io,
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::SmallRHSCoefficient, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::LargeRHSCoefficient, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::SmallObjectiveCoefficient,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::LargeObjectiveCoefficient,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::SmallObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::LargeObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::SmallMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::LargeMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function ModelAnalyzer._summarize(io::IO, ::NonconvexQuadraticObjective, model)
    return print(io, "Objective is Nonconvex quadratic")
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::NonconvexQuadraticConstraint,
    model,
)
    return print(io, ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::VariableNotInConstraints,
    model,
)
    return print(io, "Variable: ", ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::EmptyConstraint, model)
    return print(io, "Constraint: ", ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::VariableBoundAsConstraint,
    model,
)
    return print(io, "Constraint: ", ModelAnalyzer._name(issue.ref, model))
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::DenseConstraint, model)
    return print(
        io,
        "Constraint: ",
        ModelAnalyzer._name(issue.ref, model),
        " with ",
        issue.nnz,
        " non zero coefficients",
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallMatrixCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable): (",
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeMatrixCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable): (",
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallBoundCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        ModelAnalyzer._name(issue.variable, model),
        " with bound ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeBoundCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        ModelAnalyzer._name(issue.variable, model),
        " with bound ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallRHSCoefficient,
    model,
)
    return print(
        io,
        "Constraint: ",
        ModelAnalyzer._name(issue.ref, model),
        " with right-hand-side ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeRHSCoefficient,
    model,
)
    return print(
        io,
        "Constraint: ",
        ModelAnalyzer._name(issue.ref, model),
        " with right-hand-side ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallObjectiveCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        ModelAnalyzer._name(issue.variable, model),
        " with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeObjectiveCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        ModelAnalyzer._name(issue.variable, model),
        " with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Variable -- Variable): (",
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Variable -- Variable): (",
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable -- Variable): (",
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable -- Variable): (",
        ModelAnalyzer._name(issue.ref, model),
        " -- ",
        ModelAnalyzer._name(issue.variable1, model),
        " -- ",
        ModelAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::NonconvexQuadraticObjective,
    model,
)
    return ModelAnalyzer._summarize(io, issue, model)
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::NonconvexQuadraticConstraint,
    model,
)
    return print(io, "Constraint: ", ModelAnalyzer._name(issue.ref, model))
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

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{NonconvexQuadraticObjective},
)
    return data.nonconvex_objective
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{NonconvexQuadraticConstraint},
)
    return data.nonconvex_rows
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
        SmallMatrixQuadraticCoefficient,
        LargeMatrixQuadraticCoefficient,
        NonconvexQuadraticConstraint,
        NonconvexQuadraticObjective,
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
    max_issues = ModelAnalyzer.DEFAULT_MAX_ISSUES,
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

_print_value(x::Real) = Printf.@sprintf("%1.0e", x)

function _stringify_bounds(bounds::Vector{Float64})
    lower = bounds[1] < Inf ? _print_value(bounds[1]) : "0e+00"
    upper = bounds[2] > -Inf ? _print_value(bounds[2]) : "0e+00"
    return string("[", lower, ", ", upper, "]")
end

end
