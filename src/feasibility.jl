# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module Feasibility

import ModelAnalyzer
import Dualization
import MathOptInterface as MOI
import Printf

"""
    Analyzer() <: ModelAnalyzer.AbstractAnalyzer

The `Analyzer` type is used to perform feasibility analysis on a model.

## Example

```julia
julia> data = ModelAnalyzer.analyze(
    ModelAnalyzer.Feasibility.Analyzer(),
    model;
    primal_point::Union{Nothing, Dict} = nothing,
    dual_point::Union{Nothing, Dict} = nothing,
    atol::Float64 = 1e-6,
    skip_missing::Bool = false,
    dual_check = true,
);
```

The additional parameters:
- `primal_point`: The primal solution point to use for feasibility checking.
  If `nothing`, it will use the current primal solution from optimized model.
- `dual_point`: The dual solution point to use for feasibility checking.
  If `nothing` and the model can be dualized, it will use the current dual
  solution from the model.
- `atol`: The absolute tolerance for feasibility checking.
- `skip_missing`: If `true`, constraints with missing variables in the provided
  point will be ignored.
- `dual_check`: If `true`, it will perform dual feasibility checking. Disabling
  the dual check will also disable complementarity checking.
"""
struct Analyzer <: ModelAnalyzer.AbstractAnalyzer end

"""
    AbstractFeasibilityIssue <: AbstractNumericalIssue

Abstract type for feasibility issues found during the analysis of a model.
"""
abstract type AbstractFeasibilityIssue <: ModelAnalyzer.AbstractIssue end

"""
    PrimalViolation <: AbstractFeasibilityIssue

The `PrimalViolation` issue is identified when a primal constraint has a
left-hand-side value that is not within the constraint's set.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.PrimalViolation)
```
"""
struct PrimalViolation <: AbstractFeasibilityIssue
    ref::MOI.ConstraintIndex
    violation::Float64
end

"""
    DualConstraintViolation <: AbstractFeasibilityIssue

The `DualConstraintViolation` issue is identified when a dual constraint has a
value that is not within the dual constraint's set.
This dual constraint corresponds to a primal variable.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.DualConstraintViolation)
```
"""
struct DualConstraintViolation <: AbstractFeasibilityIssue
    ref::MOI.VariableIndex
    violation::Float64
end

"""
    DualConstrainedVariableViolation <: AbstractFeasibilityIssue

The `DualConstrainedVariableViolation` issue is identified when a dual 
constraint, which is a constrained varaible constraint, has a value
that is not within the dual constraint's set.
This dual constraint corresponds to a primal constraint.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.DualConstrainedVariableViolation)
```
"""
struct DualConstrainedVariableViolation <: AbstractFeasibilityIssue
    ref::MOI.ConstraintIndex
    violation::Float64
end

"""
    ComplemetarityViolation <: AbstractFeasibilityIssue

The `ComplemetarityViolation` issue is identified when a pair of primal
constraint and dual variable has a nonzero complementarity value, i.e., the
inner product of the primal constraint's slack and the dual variable's
violation is not zero.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.ComplemetarityViolation)
```
"""
struct ComplemetarityViolation <: AbstractFeasibilityIssue
    ref::MOI.ConstraintIndex
    violation::Float64
end

"""
    DualObjectiveMismatch <: AbstractFeasibilityIssue

The `DualObjectiveMismatch` issue is identified when the dual objective value
computed from problem data and the dual solution does not match the solver's
dual objective value.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.DualObjectiveMismatch)
```
"""
struct DualObjectiveMismatch <: AbstractFeasibilityIssue
    obj::Float64
    obj_solver::Float64
end

"""
    PrimalObjectiveMismatch <: AbstractFeasibilityIssue

The `PrimalObjectiveMismatch` issue is identified when the primal objective
value computed from problem data and the primal solution does not match
the solver's primal objective value.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.PrimalObjectiveMismatch)
```
"""
struct PrimalObjectiveMismatch <: AbstractFeasibilityIssue
    obj::Float64
    obj_solver::Float64
end

"""
    PrimalDualMismatch <: AbstractFeasibilityIssue

The `PrimalDualMismatch` issue is identified when the primal objective value
computed from problem data and the primal solution does not match the dual
objective value computed from problem data and the dual solution.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.PrimalDualMismatch)
```
"""
struct PrimalDualMismatch <: AbstractFeasibilityIssue
    primal::Float64
    dual::Float64
end

"""
    PrimalDualSolverMismatch <: AbstractFeasibilityIssue

The `PrimalDualSolverMismatch` issue is identified when the primal objective
value reported by the solver does not match the dual objective value reported
by the solver.

For more information, run:
```julia
julia> ModelAnalyzer.summarize(ModelAnalyzer.Feasibility.PrimalDualSolverMismatch)
```
"""
struct PrimalDualSolverMismatch <: AbstractFeasibilityIssue
    primal::Float64
    dual::Float64
end

"""
    Data

The `Data` structure holds the results of the feasibility analysis performed
by the `ModelAnalyzer.analyze` function for a model. It contains
the configuration used for the analysis, the primal and dual points, and
the lists of various feasibility issues found during the analysis.
"""
Base.@kwdef mutable struct Data <: ModelAnalyzer.AbstractData
    # analysis configuration
    primal_point::Union{Nothing,AbstractDict}
    dual_point::Union{Nothing,AbstractDict}
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

function ModelAnalyzer._summarize(io::IO, ::Type{PrimalViolation})
    return print(io, "# PrimalViolation")
end

function ModelAnalyzer._summarize(io::IO, ::Type{DualConstraintViolation})
    return print(io, "# DualConstraintViolation")
end

function ModelAnalyzer._summarize(
    io::IO,
    ::Type{DualConstrainedVariableViolation},
)
    return print(io, "# DualConstrainedVariableViolation")
end

function ModelAnalyzer._summarize(io::IO, ::Type{ComplemetarityViolation})
    return print(io, "# ComplemetarityViolation")
end

function ModelAnalyzer._summarize(io::IO, ::Type{DualObjectiveMismatch})
    return print(io, "# DualObjectiveMismatch")
end

function ModelAnalyzer._summarize(io::IO, ::Type{PrimalObjectiveMismatch})
    return print(io, "# PrimalObjectiveMismatch")
end

function ModelAnalyzer._summarize(io::IO, ::Type{PrimalDualMismatch})
    return print(io, "# PrimalDualMismatch")
end

function ModelAnalyzer._summarize(io::IO, ::Type{PrimalDualSolverMismatch})
    return print(io, "# PrimalDualSolverMismatch")
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{PrimalViolation})
    return print(
        io,
        """
        # PrimalViolation

        ## What

        A `PrimalViolation` issue is identified when a constraint has 
        function , i.e., a left-hand-side value, that is not within
        the constraint's set.

        ## Why

        This can happen due to a few reasons:
        - The solver did not converge.
        - The model is infeasible and the solver converged to an
          infeasible point.
        - The solver converged to a low accuracy solution, which might
          happen due to transformations in the the model presolve or
          due to numerical issues.

        ## How to fix

        Check the solver convergence log and the solver status. If the
        solver did not converge, you might want to try alternative
        solvers or adjust the solver options. If the solver converged
        to an infeasible point, you might want to check the model
        constraints and bounds. If the solver converged to a low
        accuracy solution, you might want to adjust the solver options
        or the model presolve.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{DualConstraintViolation},
)
    return print(
        io,
        """
        # DualConstraintViolation

        ## What

        A `DualConstraintViolation` issue is identified when a constraint has
        a dual value that is not within the dual constraint's set.

        ## Why

        This can happen due to a few reasons:
        - The solver did not converge.
        - The model is infeasible and the solver converged to an
          infeasible point.
        - The solver converged to a low accuracy solution, which might
          happen due to transformations in the the model presolve or
          due to numerical issues.

        ## How to fix

        Check the solver convergence log and the solver status. If the
        solver did not converge, you might want to try alternative
        solvers or adjust the solver options. If the solver converged
        to an infeasible point, you might want to check the model
        constraints and bounds. If the solver converged to a low
        accuracy solution, you might want to adjust the solver options
        or the model presolve.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{DualConstrainedVariableViolation},
)
    return print(
        io,
        """
        # DualConstrainedVariableViolation

        ## What

        A `DualConstrainedVariableViolation` issue is identified when a dual
        constraint, which is a constrained varaible constraint, has a value
        that is not within the dual constraint's set.

        ## Why

        This can happen due to a few reasons:
        - The solver did not converge.
        - The model is infeasible and the solver converged to an
          infeasible point.
        - The solver converged to a low accuracy solution, which might
          happen due to transformations in the the model presolve or
          due to numerical issues.

        ## How to fix

        Check the solver convergence log and the solver status. If the
        solver did not converge, you might want to try alternative
        solvers or adjust the solver options. If the solver converged
        to an infeasible point, you might want to check the model
        constraints and bounds. If the solver converged to a low
        accuracy solution, you might want to adjust the solver options
        or the model presolve.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{ComplemetarityViolation},
)
    return print(
        io,
        """
        # ComplemetarityViolation

        ## What

        A `ComplemetarityViolation` issue is identified when a pair of
        primal constraint and dual varaible has a nonzero
        complementarity value, i.e., the inner product of the primal
        constraint's slack and the dual variable's violation is
        not zero.

        ## Why

        This can happen due to a few reasons:
        - The solver did not converge.
        - The model is infeasible and the solver converged to an
          infeasible point.
        - The solver converged to a low accuracy solution, which might
          happen due to transformations in the the model presolve or
          due to numerical issues.

        ## How to fix

        Check the solver convergence log and the solver status. If the
        solver did not converge, you might want to try alternative
        solvers or adjust the solver options. If the solver converged
        to an infeasible point, you might want to check the model
        constraints and bounds. If the solver converged to a low
        accuracy solution, you might want to adjust the solver options
        or the model presolve.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{DualObjectiveMismatch})
    return print(
        io,
        """
        # DualObjectiveMismatch

        ## What

        A `DualObjectiveMismatch` issue is identified when the dual
        objective value computed from problema data and the dual
        solution does not match the solver's dual objective
        value.

        ## Why

        This can happen due to:
        - The solver performed presolve transformations and the
          reported dual objective is reported from the transformed
          problem.
        - Bad problem numerical conditioning, very large and very
          small coefficients might be present in the model.

        ## How to fix

        Check the solver convergence log and the solver status.
        Consider reviewing the coefficients of the objective function.
        Consider reviewing the options set in the solver.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{PrimalObjectiveMismatch},
)
    return print(
        io,
        """
        # PrimalObjectiveMismatch

        ## What

        A `PrimalObjectiveMismatch` issue is identified when the primal
        objective value computed from problema data and the primal
        solution does not match the solver's primal objective
        value.

        ## Why

        This can happen due to:
        - The solver performed presolve transformations and the
          reported primal objective is reported from the transformed
          problem.
        - Bad problem numerical conditioning, very large and very
          small coefficients might be present in the model.

        ## How to fix

        Check the solver convergence log and the solver status.
        Consider reviewing the coefficients of the objective function.
        Consider reviewing the options set in the solver.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(io::IO, ::Type{PrimalDualMismatch})
    return print(
        io,
        """
        # PrimalDualMismatch

        ## What

        A `PrimalDualMismatch` issue is identified when the primal
        objective value computed from problema data and the primal
        solution does not match the dual objective value computed
        from problem data and the dual solution.

        ## Why

        This can happen due to:
        - The solver did not converge.
        - Bad problem numerical conditioning, very large and very
          small coefficients might be present in the model.

        ## How to fix

        Check the solver convergence log and the solver status.
        Consider reviewing the coefficients of the model.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    ::Type{PrimalDualSolverMismatch},
)
    return print(
        io,
        """
        # PrimalDualSolverMismatch

        ## What

        A `PrimalDualSolverMismatch` issue is identified when the primal
        objective value reported by the solver does not match the dual
        objective value reported by the solver.

        ## Why

        This can happen due to:
        - The solver did not converge.

        ## How to fix

        Check the solver convergence log and the solver status.

        ## More information

        No extra information for this issue.
        """,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::PrimalViolation, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " : ",
        issue.violation,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::DualConstraintViolation, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " : ",
        issue.violation,
    )
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::DualConstrainedVariableViolation,
    model,
)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " : ",
        issue.violation,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::ComplemetarityViolation, model)
    return print(
        io,
        ModelAnalyzer._name(issue.ref, model),
        " : ",
        issue.violation,
    )
end

function ModelAnalyzer._summarize(io::IO, issue::DualObjectiveMismatch, model)
    return ModelAnalyzer._verbose_summarize(io, issue, model)
end

function ModelAnalyzer._summarize(io::IO, issue::PrimalObjectiveMismatch, model)
    return ModelAnalyzer._verbose_summarize(io, issue, model)
end

function ModelAnalyzer._summarize(io::IO, issue::PrimalDualMismatch, model)
    return ModelAnalyzer._verbose_summarize(io, issue, model)
end

function ModelAnalyzer._summarize(
    io::IO,
    issue::PrimalDualSolverMismatch,
    model,
)
    return ModelAnalyzer._verbose_summarize(io, issue, model)
end

function ModelAnalyzer._verbose_summarize(io::IO, issue::PrimalViolation, model)
    return print(
        io,
        "Constraint ",
        ModelAnalyzer._name(issue.ref, model),
        " has primal violation ",
        issue.violation,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::DualConstraintViolation,
    model,
)
    return print(
        io,
        "Variables ",
        ModelAnalyzer._name.(issue.ref, model),
        " have dual violation ",
        issue.violation,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::DualConstrainedVariableViolation,
    model,
)
    return print(
        io,
        "Constraint ",
        ModelAnalyzer._name(issue.ref, model),
        " has dual violation ",
        issue.violation,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::ComplemetarityViolation,
    model,
)
    return print(
        io,
        "Constraint ",
        ModelAnalyzer._name(issue.ref, model),
        " has complementarty violation ",
        issue.violation,
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::DualObjectiveMismatch,
    model,
)
    return print(
        io,
        "Dual objective mismatch: ",
        issue.obj,
        " (computed) vs ",
        issue.obj_solver,
        " (reported by solver)\n",
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::PrimalObjectiveMismatch,
    model,
)
    return print(
        io,
        "Primal objective mismatch: ",
        issue.obj,
        " (computed) vs ",
        issue.obj_solver,
        " (reported by solver)\n",
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::PrimalDualMismatch,
    model,
)
    return print(
        io,
        "Primal dual mismatch: ",
        issue.primal,
        " (computed primal) vs ",
        issue.dual,
        " (computed dual)\n",
    )
end

function ModelAnalyzer._verbose_summarize(
    io::IO,
    issue::PrimalDualSolverMismatch,
    model,
)
    return print(
        io,
        "Solver reported objective mismatch: ",
        issue.primal,
        " (reported primal) vs ",
        issue.dual,
        " (reported dual)\n",
    )
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{PrimalViolation})
    return data.primal
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{DualConstraintViolation},
)
    return data.dual
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{DualConstrainedVariableViolation},
)
    return data.dual_convar
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{ComplemetarityViolation},
)
    return data.complementarity
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{DualObjectiveMismatch})
    return data.dual_objective_mismatch
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{PrimalObjectiveMismatch},
)
    return data.primal_objective_mismatch
end

function ModelAnalyzer.list_of_issues(data::Data, ::Type{PrimalDualMismatch})
    return data.primal_dual_mismatch
end

function ModelAnalyzer.list_of_issues(
    data::Data,
    ::Type{PrimalDualSolverMismatch},
)
    return data.primal_dual_solver_mismatch
end

function ModelAnalyzer.list_of_issue_types(data::Data)
    ret = Type[]
    for type in (
        PrimalViolation,
        DualConstraintViolation,
        DualConstrainedVariableViolation,
        ComplemetarityViolation,
        DualObjectiveMismatch,
        PrimalObjectiveMismatch,
        PrimalDualMismatch,
        PrimalDualSolverMismatch,
    )
        if !isempty(ModelAnalyzer.list_of_issues(data, type))
            push!(ret, type)
        end
    end
    return ret
end

function summarize_configurations(io::IO, data::Data)
    print(io, "## Configuration\n\n")
    # print(io, "  - point: ", data.point, "\n")
    print(io, "  atol: ", data.atol, "\n")
    print(io, "  skip_missing: ", data.skip_missing, "\n")
    return
end

function ModelAnalyzer.summarize(
    io::IO,
    data::Data;
    model = nothing,
    verbose = true,
    max_issues = ModelAnalyzer.DEFAULT_MAX_ISSUES,
    configurations = true,
)
    print(io, "## Feasibility Analysis\n\n")
    if configurations
        summarize_configurations(io, data)
        print(io, "\n")
    end
    # add maximum primal, dual and compl
    # add sum of primal, dual and compl
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
    return print(io, "Feasibility analysis found $n issues")
end

function ModelAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike;
    primal_point = nothing,
    dual_point = nothing,
    atol::Float64 = 1e-6,
    skip_missing::Bool = false,
    dual_check = true,
)
    can_dualize = false
    if dual_check
        can_dualize = _can_dualize(model)
        if !can_dualize
            println(
                "The model cannot be dualized. Automatically setting `dual_check = false`.",
            )
            dual_check = false
        end
    end

    data = Data(
        primal_point = primal_point,
        dual_point = dual_point,
        atol = atol,
        skip_missing = skip_missing,
        dual_check = dual_check,
    )

    if data.primal_point === nothing
        primal_status = MOI.get(model, MOI.PrimalStatus())
        if !(primal_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT))
            error(
                "No primal solution is available. You must provide a point at " *
                "which to check feasibility.",
            )
        end
        data.primal_point = _last_primal_solution(model)
    end

    if data.dual_point === nothing && dual_check
        dual_status = MOI.get(model, MOI.DualStatus())
        if !(dual_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT))
            error(
                "No dual solution is available. You must provide a point at " *
                "which to check feasibility. Or set dual_check = false.",
            )
        end
        data.dual_point = _last_dual_solution(model)
    end

    _analyze_primal!(model, data)
    _dual_model = nothing
    _map = nothing
    if dual_check
        dual_problem =
            Dualization.dualize(model, consider_constrained_variables = false)
        _dual_model = dual_problem.dual_model
        _map = dual_problem.primal_dual_map
        _analyze_dual!(model, _dual_model, _map, data)
        _analyze_complementarity!(model, data)
    end
    _analyze_objectives!(model, _dual_model, _map, data)
    sort!(data.primal, by = x -> abs(x.violation))
    sort!(data.dual, by = x -> abs(x.violation))
    sort!(data.complementarity, by = x -> abs(x.violation))
    return data
end

function _analyze_primal!(model, data)
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            func = MOI.get(model, MOI.ConstraintFunction(), con)
            failed = false
            val = MOI.Utilities.eval_variables(model, func) do var_idx
                if !haskey(data.primal_point, var_idx)
                    if data.skip_missing
                        failed = true
                        return NaN # nothing
                    else
                        error(
                            "Missing variable in primal point: $var_idx. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return data.primal_point[var_idx]
            end
            if failed
                continue
            end
            set = MOI.get(model, MOI.ConstraintSet(), con)
            dist = MOI.Utilities.distance_to_set(val, set)
            if dist > data.atol
                push!(data.primal, PrimalViolation(con, dist))
            end
        end
    end
    return
end

function _dual_point_to_dual_model_ref(
    primal_model,
    map::Dualization.PrimalDualMap,
    dual_point,
)
    new_dual_point = Dict{MOI.VariableIndex,Number}()
    dual_var_to_primal_con = Dict{MOI.VariableIndex,MOI.ConstraintIndex}()
    dual_con_to_primal_con = Dict{MOI.ConstraintIndex,MOI.ConstraintIndex}()
    for (primal_con, val) in dual_point
        dual_vars = Dualization._get_dual_variables(map, primal_con)
        if length(dual_vars) != length(val)
            error(
                "The dual point entry for constraint $primal_con has " *
                "length $(length(val)) but the dual variable " *
                "length is $(length(dual_vars)).",
            )
        end
        for (idx, dual_var) in enumerate(dual_vars)
            new_dual_point[dual_var] = val[idx]
            dual_var_to_primal_con[dual_var] = primal_con
        end
        dual_con = Dualization._get_dual_constraint(map, primal_con)
        if dual_con !== nothing
            dual_con_to_primal_con[dual_con] = primal_con
            # else
            #     if !(primal_con isa MOI.ConstraintIndex{MOI.VariableIndex,<:MOI.EqualTo} ||
            #         primal_con isa MOI.ConstraintIndex{MOI.VectorOfVariables,MOI.Zeros}
            #         SAF in EQ, etc...
            #) 
            #         error("Problem with dualization, see: $primal_con")
            #     end
        end
    end
    primal_vars = MOI.get(primal_model, MOI.ListOfVariableIndices())
    dual_con_to_primal_vars =
        Dict{MOI.ConstraintIndex,Vector{MOI.VariableIndex}}()
    for primal_var in primal_vars
        dual_con, idx = Dualization._get_dual_constraint(map, primal_var)
        # TODO
        idx = max(idx, 1)
        if haskey(dual_con_to_primal_vars, dual_con)
            vec = dual_con_to_primal_vars[dual_con]
            if idx > length(vec)
                resize!(vec, idx)
            end
            vec[idx] = primal_var
        else
            vec = Vector{MOI.VariableIndex}(undef, idx)
            vec[idx] = primal_var
            dual_con_to_primal_vars[dual_con] = vec
        end
    end
    return new_dual_point,
    dual_var_to_primal_con,
    dual_con_to_primal_vars,
    dual_con_to_primal_con
end

function _analyze_dual!(model, dual_model, map, data)
    dual_point,
    dual_var_to_primal_con,
    dual_con_to_primal_vars,
    dual_con_to_primal_con =
        _dual_point_to_dual_model_ref(model, map, data.dual_point)
    types = MOI.get(dual_model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(dual_model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            func = MOI.get(dual_model, MOI.ConstraintFunction(), con)
            failed = false
            val = MOI.Utilities.eval_variables(dual_model, func) do var_idx
                if !haskey(dual_point, var_idx)
                    if data.skip_missing
                        failed = true
                        return NaN # nothing
                    else
                        primal_con = dual_var_to_primal_con[var_idx]
                        error(
                            "Missing data for dual of constraint: $primal_con. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return dual_point[var_idx]
            end
            if failed
                continue
            end
            set = MOI.get(dual_model, MOI.ConstraintSet(), con)
            dist = MOI.Utilities.distance_to_set(val, set)
            if dist > data.atol
                if haskey(dual_con_to_primal_vars, con)
                    vars = dual_con_to_primal_vars[con]
                    if length(vars) != 1
                        # TODO improve error
                        error(
                            "The dual constraint $con has " *
                            "length $(length(vars)) != 1",
                        )
                    end
                    push!(data.dual, DualConstraintViolation(vars[], dist))
                else
                    con = dual_con_to_primal_con[con]
                    push!(
                        data.dual_convar,
                        DualConstrainedVariableViolation(con, dist),
                    )
                end
            end
        end
    end
    return
end

function _analyze_complementarity!(model, data)
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            func = MOI.get(model, MOI.ConstraintFunction(), con)
            failed = false
            val = MOI.Utilities.eval_variables(model, func) do var_idx
                if !haskey(data.primal_point, var_idx)
                    if data.skip_missing
                        failed = true
                        return NaN # nothing
                    else
                        error(
                            "Missing variable in primal point: $var_idx. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return data.primal_point[var_idx]
            end
            set = MOI.get(model, MOI.ConstraintSet(), con)
            val = val - _set_value(set)
            if failed
                continue
            end
            if !haskey(data.dual_point, con)
                if data.skip_missing
                    continue
                else
                    error(
                        "Missing dual value for constraint: $con. " *
                        "Set skip_missing = true to ignore this error.",
                    )
                end
            end
            if length(data.dual_point[con]) != length(val)
                error(
                    "The dual point entry for constraint $con has " *
                    "length $(length(data.dual_point[con])) but the primal " *
                    "constraint length is $(length(val)) .",
                )
            end
            comp_val = MOI.Utilities.set_dot(val, data.dual_point[con], set)
            if abs(comp_val) > data.atol
                push!(
                    data.complementarity,
                    ComplemetarityViolation(con, comp_val),
                )
            end
        end
    end
    return
end

# not needed because it would have stoped in dualization before
# function _set_value(set::MOI.AbstractScalarSet)
#     return 0.0
# end
# function _set_value(set::MOI.Interval)
#     error("Interval sets are not supported.")
#     return (set.lower, set.upper)
# end

function _set_value(set::MOI.AbstractVectorSet)
    return zeros(MOI.dimension(set))
end

function _set_value(set::MOI.LessThan)
    return set.upper
end

function _set_value(set::MOI.GreaterThan)
    return set.lower
end

function _set_value(set::MOI.EqualTo)
    return set.value
end

function _analyze_objectives!(model::MOI.ModelLike, dual_model, map, data)
    primal_status = MOI.get(model, MOI.PrimalStatus())
    dual_status = MOI.get(model, MOI.DualStatus())
    if primal_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
        obj_val_solver = MOI.get(model, MOI.ObjectiveValue())
    else
        obj_val_solver = nothing
    end

    if dual_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
        dual_obj_val_solver = MOI.get(model, MOI.DualObjectiveValue())
    else
        dual_obj_val_solver = nothing
    end

    if dual_obj_val_solver !== nothing &&
       obj_val_solver !== nothing &&
       !isapprox(obj_val_solver, dual_obj_val_solver; atol = data.atol)
        push!(
            data.primal_dual_solver_mismatch,
            PrimalDualSolverMismatch(obj_val_solver, dual_obj_val_solver),
        )
    end

    obj_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj_func = MOI.get(model, MOI.ObjectiveFunction{obj_type}())
    obj_val = MOI.Utilities.eval_variables(model, obj_func) do var_idx
        if !haskey(data.primal_point, var_idx)
            if data.skip_missing
                return NaN # nothing
            else
                error(
                    "Missing variable in primal point: $var_idx. " *
                    "Set skip_missing = true to ignore this error.",
                )
            end
        end
        return data.primal_point[var_idx]
    end

    if obj_val_solver !== nothing &&
       !isapprox(obj_val, obj_val_solver; atol = data.atol)
        push!(
            data.primal_objective_mismatch,
            PrimalObjectiveMismatch(obj_val, obj_val_solver),
        )
    end

    if dual_model !== nothing && data.dual_point !== nothing
        dual_point, dual_var_to_primal_con, _, _ =
            _dual_point_to_dual_model_ref(model, map, data.dual_point)

        obj_type = MOI.get(dual_model, MOI.ObjectiveFunctionType())
        obj_func = MOI.get(dual_model, MOI.ObjectiveFunction{obj_type}())
        dual_obj_val =
            MOI.Utilities.eval_variables(dual_model, obj_func) do var_idx
                if !haskey(dual_point, var_idx)
                    if data.skip_missing
                        return NaN # nothing
                    else
                        primal_con = dual_var_to_primal_con[var_idx]
                        error(
                            "Missing data for dual of constraint: $primal_con. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return dual_point[var_idx]
            end

        if dual_obj_val_solver !== nothing &&
           !isapprox(dual_obj_val, dual_obj_val_solver; atol = data.atol)
            push!(
                data.dual_objective_mismatch,
                DualObjectiveMismatch(dual_obj_val, dual_obj_val_solver),
            )
        end

        if !isapprox(obj_val, dual_obj_val; atol = data.atol)
            push!(
                data.primal_dual_mismatch,
                PrimalDualMismatch(obj_val, dual_obj_val),
            )
        end
    end

    return
end

function _last_primal_solution(model::MOI.ModelLike)
    variables = MOI.get(model, MOI.ListOfVariableIndices())
    return Dict(v => MOI.get(model, MOI.VariablePrimal(), v) for v in variables)
end

function _last_dual_solution(model::MOI.ModelLike)
    ret = Dict{MOI.ConstraintIndex,Union{Number,Vector{<:Number}}}()
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            val = MOI.get(model, MOI.ConstraintDual(), con)
            ret[con] = val
        end
    end
    return ret
end

function _can_dualize(model::MOI.ModelLike)
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())

    for (F, S) in types
        if !Dualization.supported_constraint(F, S)
            return false
        end
    end

    F = MOI.get(model, MOI.ObjectiveFunctionType())

    if !Dualization.supported_objective(F)
        return false
    end

    sense = MOI.get(model, MOI.ObjectiveSense())
    if sense == MOI.FEASIBILITY_SENSE
        return false
    end

    return true
end

end # module
