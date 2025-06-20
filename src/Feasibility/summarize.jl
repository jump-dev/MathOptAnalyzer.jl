# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

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
        During the dualization  process, each primal constraint is mapped to a dual
        variable, this dual variable is tipically a constrained variable with the
        dual set of the primal constraint. If the primal constraint is a an equality
        type constraint, the dual variable is a free variable, hence, not constrained
        (dual) variable.

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
