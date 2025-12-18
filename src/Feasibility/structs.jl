# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

"""
    Analyzer() <: MathOptAnalyzer.AbstractAnalyzer

The `Analyzer` type is used to perform feasibility analysis on a model.

## Example

```julia
julia> data = MathOptAnalyzer.analyze(
    MathOptAnalyzer.Feasibility.Analyzer(),
    model;
    primal_point::Union{Nothing, Dict} = nothing,
    dual_point::Union{Nothing, Dict} = nothing,
    primal_objective::Union{Nothing, Float64} = nothing,
    dual_objective::Union{Nothing, Float64} = nothing,
    atol::Float64 = 1e-6,
    skip_missing::Bool = false,
    dual_check::Bool = true,
);
```

The additional parameters:
- `primal_point`: The primal solution point to use for feasibility checking.
  If `nothing`, it will use the current primal solution from optimized model.
- `dual_point`: The dual solution point to use for feasibility checking.
  If `nothing` and the model can be dualized, it will use the current dual
  solution from the model.
- `primal_objective`: The primal objective value considered as the solver
  objective. If `nothing`, it will use the current primal objective value from
  the model (solver).
- `dual_objective`: The dual objective value considered as the solver
  objective. If `nothing`, it will use the current dual objective value from
  the model (solver).
- `atol`: The absolute tolerance for feasibility checking.
- `skip_missing`: If `true`, constraints with missing variables in the provided
  point will be ignored.
- `dual_check`: If `true`, it will perform dual feasibility checking if the
  model is compatible with Dualization.jl. Disabling the dual check will also
  disable complementarity checking and dual objective checks.
"""
struct Analyzer <: MathOptAnalyzer.AbstractAnalyzer end

"""
    AbstractFeasibilityIssue <: AbstractNumericalIssue

Abstract type for feasibility issues found during the analysis of a model.
"""
abstract type AbstractFeasibilityIssue <: MathOptAnalyzer.AbstractIssue end

"""
    PrimalViolation <: AbstractFeasibilityIssue

The `PrimalViolation` issue is identified when a primal constraint has a
left-hand-side value that is not within the constraint's set.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.PrimalViolation)
```
"""
struct PrimalViolation <: AbstractFeasibilityIssue
    ref::MOI.ConstraintIndex
    violation::Float64
end

MathOptAnalyzer.constraint(issue::PrimalViolation) = issue.ref

MathOptAnalyzer.value(issue::PrimalViolation) = issue.violation

"""
    DualConstraintViolation <: AbstractFeasibilityIssue

The `DualConstraintViolation` issue is identified when a dual constraint has a
value that is not within the dual constraint's set.
This dual constraint corresponds to a primal variable.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.DualConstraintViolation)
```
"""
struct DualConstraintViolation <: AbstractFeasibilityIssue
    ref::MOI.VariableIndex
    violation::Float64
end

MathOptAnalyzer.variable(issue::DualConstraintViolation) = issue.ref

MathOptAnalyzer.value(issue::DualConstraintViolation) = issue.violation

"""
    DualConstrainedVariableViolation <: AbstractFeasibilityIssue

The `DualConstrainedVariableViolation` issue is identified when a dual
constraint, which is a constrained varaible constraint, has a value
that is not within the dual constraint's set.
During the dualization  process, each primal constraint is mapped to a dual
variable, this dual variable is tipically a constrained variable with the
dual set of the primal constraint. If the primal constraint is a an equality
type constraint, the dual variable is a free variable, hence, not constrained
(dual) variable.
This dual constraint corresponds to a primal (non-equality) constraint.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation)
```
"""
struct DualConstrainedVariableViolation <: AbstractFeasibilityIssue
    ref::MOI.ConstraintIndex
    violation::Float64
end

MathOptAnalyzer.constraint(issue::DualConstrainedVariableViolation) = issue.ref

MathOptAnalyzer.value(issue::DualConstrainedVariableViolation) = issue.violation

"""
    ComplemetarityViolation <: AbstractFeasibilityIssue

The `ComplemetarityViolation` issue is identified when a pair of primal
constraint and dual variable has a nonzero complementarity value, i.e., the
inner product of the primal constraint's slack and the dual variable's
violation is not zero.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.ComplemetarityViolation)
```
"""
struct ComplemetarityViolation <: AbstractFeasibilityIssue
    ref::MOI.ConstraintIndex
    violation::Float64
end

MathOptAnalyzer.constraint(issue::ComplemetarityViolation) = issue.ref

MathOptAnalyzer.value(issue::ComplemetarityViolation) = issue.violation

"""
    DualObjectiveMismatch <: AbstractFeasibilityIssue

The `DualObjectiveMismatch` issue is identified when the dual objective value
computed from problem data and the dual solution does not match the solver's
dual objective value.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.DualObjectiveMismatch)
```
"""
struct DualObjectiveMismatch <: AbstractFeasibilityIssue
    obj::Float64
    obj_solver::Float64
end

# MathOptAnalyzer.values(issue::DualObjectiveMismatch) = [issue.obj, issue.obj_solver]

"""
    PrimalObjectiveMismatch <: AbstractFeasibilityIssue

The `PrimalObjectiveMismatch` issue is identified when the primal objective
value computed from problem data and the primal solution does not match
the solver's primal objective value.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.PrimalObjectiveMismatch)
```
"""
struct PrimalObjectiveMismatch <: AbstractFeasibilityIssue
    obj::Float64
    obj_solver::Float64
end

# MathOptAnalyzer.values(issue::PrimalObjectiveMismatch) = [issue.obj, issue.obj_solver]

"""
    PrimalDualMismatch <: AbstractFeasibilityIssue

The `PrimalDualMismatch` issue is identified when the primal objective value
computed from problem data and the primal solution does not match the dual
objective value computed from problem data and the dual solution.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.PrimalDualMismatch)
```
"""
struct PrimalDualMismatch <: AbstractFeasibilityIssue
    primal::Float64
    dual::Float64
end

MathOptAnalyzer.values(issue::PrimalDualMismatch) = [issue.primal, issue.dual]

"""
    PrimalDualSolverMismatch <: AbstractFeasibilityIssue

The `PrimalDualSolverMismatch` issue is identified when the primal objective
value reported by the solver does not match the dual objective value reported
by the solver.

For more information, run:
```julia
julia> MathOptAnalyzer.summarize(MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch)
```
"""
struct PrimalDualSolverMismatch <: AbstractFeasibilityIssue
    primal::Float64
    dual::Float64
end

# MathOptAnalyzer.values(issue::PrimalDualSolverMismatch) = [issue.primal, issue.dual]

"""
    Data

The `Data` structure holds the results of the feasibility analysis performed
by the `MathOptAnalyzer.analyze` function for a model. It contains
the configuration used for the analysis, the primal and dual points, and
the lists of various feasibility issues found during the analysis.
"""
Base.@kwdef mutable struct Data <: MathOptAnalyzer.AbstractData
    # analysis configuration
    primal_point::Union{Nothing,AbstractDict}
    dual_point::Union{Nothing,AbstractDict}
    primal_objective::Union{Nothing,Float64}
    dual_objective::Union{Nothing,Float64}
    atol::Float64
    skip_missing::Bool
    dual_check::Bool
    # analysis results
    primal::Vector{PrimalViolation} = PrimalViolation[]
    dual::Vector{DualConstraintViolation} = DualConstraintViolation[]
    dual_convar::Vector{DualConstrainedVariableViolation} =
        DualConstrainedVariableViolation[]
    complementarity::Vector{ComplemetarityViolation} = ComplemetarityViolation[]
    # objective analysis
    dual_objective_mismatch::Vector{DualObjectiveMismatch} =
        DualObjectiveMismatch[]
    primal_objective_mismatch::Vector{PrimalObjectiveMismatch} =
        PrimalObjectiveMismatch[]
    primal_dual_mismatch::Vector{PrimalDualMismatch} = PrimalDualMismatch[]
    primal_dual_solver_mismatch::Vector{PrimalDualSolverMismatch} =
        PrimalDualSolverMismatch[]
end
