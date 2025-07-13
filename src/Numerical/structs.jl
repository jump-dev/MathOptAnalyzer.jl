# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

"""
    Analyzer() <: MathOptAnalyzer.AbstractAnalyzer

The `Analyzer` type is used to analyze the coefficients of a model for
numerical issues.

## Example

```julia
julia> data = MathOptAnalyzer.analyze(
    MathOptAnalyzer.Numerical.Analyzer(),
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
struct Analyzer <: MathOptAnalyzer.AbstractAnalyzer end

"""
    AbstractNumericalIssue <: AbstractNumericalIssue

Abstract type for numerical issues found during the analysis of a model.
"""
abstract type AbstractNumericalIssue <: MathOptAnalyzer.AbstractIssue end

"""
    VariableNotInConstraints <: AbstractNumericalIssue

The `VariableNotInConstraints` issue is identified when a variable appears in no
constraints.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.VariableNotInConstraints)
```
"""
struct VariableNotInConstraints <: AbstractNumericalIssue
    ref::MOI.VariableIndex
end

MathOptAnalyzer.variable(issue::VariableNotInConstraints) = issue.ref

"""
    EmptyConstraint <: AbstractNumericalIssue

The `EmptyConstraint` issue is identified when a constraint has no coefficients
different from zero.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.EmptyConstraint)
```
"""
struct EmptyConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
end

MathOptAnalyzer.constraint(issue::EmptyConstraint) = issue.ref

"""
    VariableBoundAsConstraint <: AbstractNumericalIssue

The `VariableBoundAsConstraint` issue is identified when a constraint is
equivalent to a variable bound, that is, the constraint has only one non-zero
coefficient, and this coefficient is equal to one.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.VariableBoundAsConstraint)
```
"""
struct VariableBoundAsConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
end

MathOptAnalyzer.constraint(issue::VariableBoundAsConstraint) = issue.ref

"""
    DenseConstraint <: AbstractNumericalIssue

The `DenseConstraint` issue is identified when a constraint has a fraction of
non-zero entries greater than `threshold_dense_fill_in` and the number of
non-zero entries is greater than `threshold_dense_entries`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.DenseConstraint)
```
"""
struct DenseConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    nnz::Int
end

MathOptAnalyzer.constraint(issue::DenseConstraint) = issue.ref

MathOptAnalyzer.value(issue::DenseConstraint) = issue.nnz

"""
    SmallMatrixCoefficient <: AbstractNumericalIssue

The `SmallMatrixCoefficient` issue is identified when a matrix coefficient in a
constraint is smaller than `threshold_small`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.SmallMatrixCoefficient)
```
"""
struct SmallMatrixCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable::MOI.VariableIndex
    coefficient::Float64
end

MathOptAnalyzer.variable(issue::SmallMatrixCoefficient) = issue.variable

MathOptAnalyzer.constraint(issue::SmallMatrixCoefficient) = issue.ref

MathOptAnalyzer.value(issue::SmallMatrixCoefficient) = issue.coefficient

"""
    LargeMatrixCoefficient <: AbstractNumericalIssue

The `LargeMatrixCoefficient` issue is identified when a matrix coefficient in a
constraint is larger than `threshold_large`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.LargeMatrixCoefficient)
```
"""
struct LargeMatrixCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable::MOI.VariableIndex
    coefficient::Float64
end

MathOptAnalyzer.variable(issue::LargeMatrixCoefficient) = issue.variable

MathOptAnalyzer.constraint(issue::LargeMatrixCoefficient) = issue.ref

MathOptAnalyzer.value(issue::LargeMatrixCoefficient) = issue.coefficient

"""
    SmallBoundCoefficient <: AbstractNumericalIssue

The `SmallBoundCoefficient` issue is identified when a variable's bound
(coefficient) is smaller than `threshold_small`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.SmallBoundCoefficient)
```
"""
struct SmallBoundCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end

MathOptAnalyzer.variable(issue::SmallBoundCoefficient) = issue.variable

MathOptAnalyzer.value(issue::SmallBoundCoefficient) = issue.coefficient

"""
    LargeBoundCoefficient <: AbstractNumericalIssue

The `LargeBoundCoefficient` issue is identified when a variable's bound
(coefficient) is larger than `threshold_large`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.LargeBoundCoefficient)
```
"""
struct LargeBoundCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end

MathOptAnalyzer.variable(issue::LargeBoundCoefficient) = issue.variable

MathOptAnalyzer.value(issue::LargeBoundCoefficient) = issue.coefficient

"""
    SmallRHSCoefficient <: AbstractNumericalIssue

The `SmallRHSCoefficient` issue is identified when the right-hand-side (RHS)
coefficient of a constraint is smaller than `threshold_small`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.SmallRHSCoefficient)
```
"""
struct SmallRHSCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    coefficient::Float64
end

MathOptAnalyzer.constraint(issue::SmallRHSCoefficient) = issue.ref

MathOptAnalyzer.value(issue::SmallRHSCoefficient) = issue.coefficient

"""
    LargeRHSCoefficient <: AbstractNumericalIssue

The `LargeRHSCoefficient` issue is identified when the right-hand-side (RHS)
coefficient of a constraint is larger than `threshold_large`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.LargeRHSCoefficient)
```
"""
struct LargeRHSCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    coefficient::Float64
end

MathOptAnalyzer.constraint(issue::LargeRHSCoefficient) = issue.ref

MathOptAnalyzer.value(issue::LargeRHSCoefficient) = issue.coefficient

"""
    SmallObjectiveCoefficient <: AbstractNumericalIssue

The `SmallObjectiveCoefficient` issue is identified when a coefficient in the
objective function is smaller than `threshold_small`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.SmallObjectiveCoefficient)
```
"""
struct SmallObjectiveCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end

MathOptAnalyzer.variable(issue::SmallObjectiveCoefficient) = issue.variable

MathOptAnalyzer.value(issue::SmallObjectiveCoefficient) = issue.coefficient

"""
    LargeObjectiveCoefficient <: AbstractNumericalIssue

The `LargeObjectiveCoefficient` issue is identified when a coefficient in the
objective function is larger than `threshold_large`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Numerical.LargeObjectiveCoefficient)
```
"""
struct LargeObjectiveCoefficient <: AbstractNumericalIssue
    variable::MOI.VariableIndex
    coefficient::Float64
end

MathOptAnalyzer.variable(issue::LargeObjectiveCoefficient) = issue.variable

MathOptAnalyzer.value(issue::LargeObjectiveCoefficient) = issue.coefficient

"""
    SmallObjectiveQuadraticCoefficient <: AbstractNumericalIssue

The `SmallObjectiveQuadraticCoefficient` issue is identified when a quadratic
coefficient in the objective function is smaller than `threshold_small`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(
    MathOptAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient
)
```
"""
struct SmallObjectiveQuadraticCoefficient <: AbstractNumericalIssue
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end

function MathOptAnalyzer.variables(issue::SmallObjectiveQuadraticCoefficient)
    return [issue.variable1, issue.variable2]
end

function MathOptAnalyzer.value(issue::SmallObjectiveQuadraticCoefficient)
    return issue.coefficient
end

"""
    LargeObjectiveQuadraticCoefficient <: AbstractNumericalIssue

The `LargeObjectiveQuadraticCoefficient` issue is identified when a quadratic
coefficient in the objective function is larger than `threshold_large`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(
    MathOptAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient
)
```
"""
struct LargeObjectiveQuadraticCoefficient <: AbstractNumericalIssue
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end

function MathOptAnalyzer.variables(issue::LargeObjectiveQuadraticCoefficient)
    return [issue.variable1, issue.variable2]
end

function MathOptAnalyzer.value(issue::LargeObjectiveQuadraticCoefficient)
    return issue.coefficient
end

"""
    SmallMatrixQuadraticCoefficient <: AbstractNumericalIssue

The `SmallMatrixQuadraticCoefficient` issue is identified when a quadratic
coefficient in a constraint is smaller than `threshold_small`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(
    MathOptAnalyzer.Numerical.SmallMatrixQuadraticCoefficient
)
```
"""
struct SmallMatrixQuadraticCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end

function MathOptAnalyzer.variables(issue::SmallMatrixQuadraticCoefficient)
    return [issue.variable1, issue.variable2]
end

function MathOptAnalyzer.constraint(issue::SmallMatrixQuadraticCoefficient)
    return issue.ref
end

MathOptAnalyzer.value(issue::SmallMatrixQuadraticCoefficient) = issue.coefficient

"""
    LargeMatrixQuadraticCoefficient <: AbstractNumericalIssue

The `LargeMatrixQuadraticCoefficient` issue is identified when a quadratic
coefficient in a constraint is larger than `threshold_large`.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(
    MathOptAnalyzer.Numerical.LargeMatrixQuadraticCoefficient
)
```
"""
struct LargeMatrixQuadraticCoefficient <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
    variable1::MOI.VariableIndex
    variable2::MOI.VariableIndex
    coefficient::Float64
end

function MathOptAnalyzer.variables(issue::LargeMatrixQuadraticCoefficient)
    return [issue.variable1, issue.variable2]
end

function MathOptAnalyzer.constraint(issue::LargeMatrixQuadraticCoefficient)
    return issue.ref
end

MathOptAnalyzer.value(issue::LargeMatrixQuadraticCoefficient) = issue.coefficient

"""
    NonconvexQuadraticObjective <: AbstractNumericalIssue

The `NonconvexQuadraticObjective` issue is identified when a quadratic
objective function is non-convex.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(
    MathOptAnalyzer.Numerical.NonconvexQuadraticObjective
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
julia> MathOptAnalyzer.summarize(
    MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint
)
```
"""
struct NonconvexQuadraticConstraint <: AbstractNumericalIssue
    ref::MOI.ConstraintIndex
end
MathOptAnalyzer.constraint(issue::NonconvexQuadraticConstraint) = issue.ref

"""
    Data

The `Data` structure holds the results of the analysis performed by the
`MathOptAnalyzer.Numerical.Analyzer`. It contains various thresholds and the
information about the model's variables, constraints, and objective function.
"""
Base.@kwdef mutable struct Data <: MathOptAnalyzer.AbstractData
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
