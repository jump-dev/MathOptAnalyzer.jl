# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function MathOptAnalyzer._summarize(io::IO, ::Type{VariableNotInConstraints})
    return print(io, "# VariableNotInConstraints")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{EmptyConstraint})
    return print(io, "# EmptyConstraint")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{VariableBoundAsConstraint})
    return print(io, "# VariableBoundAsConstraint")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{DenseConstraint})
    return print(io, "# DenseConstraint")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{SmallMatrixCoefficient})
    return print(io, "# SmallMatrixCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{LargeMatrixCoefficient})
    return print(io, "# LargeMatrixCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{SmallBoundCoefficient})
    return print(io, "# SmallBoundCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{LargeBoundCoefficient})
    return print(io, "# LargeBoundCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{SmallRHSCoefficient})
    return print(io, "# SmallRHSCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{LargeRHSCoefficient})
    return print(io, "# LargeRHSCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{SmallObjectiveCoefficient})
    return print(io, "# SmallObjectiveCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{LargeObjectiveCoefficient})
    return print(io, "# LargeObjectiveCoefficient")
end

function MathOptAnalyzer._summarize(
    io::IO,
    ::Type{SmallObjectiveQuadraticCoefficient},
)
    return print(io, "# SmallObjectiveQuadraticCoefficient")
end

function MathOptAnalyzer._summarize(
    io::IO,
    ::Type{LargeObjectiveQuadraticCoefficient},
)
    return print(io, "# LargeObjectiveQuadraticCoefficient")
end

function MathOptAnalyzer._summarize(
    io::IO,
    ::Type{SmallMatrixQuadraticCoefficient},
)
    return print(io, "# SmallMatrixQuadraticCoefficient")
end

function MathOptAnalyzer._summarize(
    io::IO,
    ::Type{LargeMatrixQuadraticCoefficient},
)
    return print(io, "# LargeMatrixQuadraticCoefficient")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{NonconvexQuadraticObjective})
    return print(io, "# NonconvexQuadraticObjective")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{NonconvexQuadraticConstraint})
    return print(io, "# NonconvexQuadraticConstraint")
end

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{EmptyConstraint})
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{DenseConstraint})
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{SmallBoundCoefficient})
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

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{LargeBoundCoefficient})
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

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{SmallRHSCoefficient})
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

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{LargeRHSCoefficient})
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._summarize(
    io::IO,
    issue::VariableNotInConstraints,
    model,
)
    return print(io, MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._summarize(io::IO, issue::EmptyConstraint, model)
    return print(io, MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::VariableBoundAsConstraint,
    model,
)
    return print(io, MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._summarize(io::IO, issue::DenseConstraint, model)
    return print(io, MathOptAnalyzer._name(issue.ref, model), " : ", issue.nnz)
end

function MathOptAnalyzer._summarize(io::IO, issue::SmallMatrixCoefficient, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(io::IO, issue::LargeMatrixCoefficient, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(io::IO, issue::SmallBoundCoefficient, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(io::IO, issue::LargeBoundCoefficient, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(io::IO, issue::SmallRHSCoefficient, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.ref, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(io::IO, issue::LargeRHSCoefficient, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.ref, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::SmallObjectiveCoefficient,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::LargeObjectiveCoefficient,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::SmallObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::LargeObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::SmallMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::LargeMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        " : ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._summarize(io::IO, ::NonconvexQuadraticObjective, model)
    return print(io, "Objective is Nonconvex quadratic")
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::NonconvexQuadraticConstraint,
    model,
)
    return print(io, MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::VariableNotInConstraints,
    model,
)
    return print(io, "Variable: ", MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._verbose_summarize(io::IO, issue::EmptyConstraint, model)
    return print(io, "Constraint: ", MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::VariableBoundAsConstraint,
    model,
)
    return print(io, "Constraint: ", MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer._verbose_summarize(io::IO, issue::DenseConstraint, model)
    return print(
        io,
        "Constraint: ",
        MathOptAnalyzer._name(issue.ref, model),
        " with ",
        issue.nnz,
        " non zero coefficients",
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallMatrixCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable): (",
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeMatrixCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable): (",
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallBoundCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        MathOptAnalyzer._name(issue.variable, model),
        " with bound ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeBoundCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        MathOptAnalyzer._name(issue.variable, model),
        " with bound ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallRHSCoefficient,
    model,
)
    return print(
        io,
        "Constraint: ",
        MathOptAnalyzer._name(issue.ref, model),
        " with right-hand-side ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeRHSCoefficient,
    model,
)
    return print(
        io,
        "Constraint: ",
        MathOptAnalyzer._name(issue.ref, model),
        " with right-hand-side ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallObjectiveCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        MathOptAnalyzer._name(issue.variable, model),
        " with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeObjectiveCoefficient,
    model,
)
    return print(
        io,
        "Variable: ",
        MathOptAnalyzer._name(issue.variable, model),
        " with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Variable -- Variable): (",
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeObjectiveQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Variable -- Variable): (",
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::SmallMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable -- Variable): (",
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::LargeMatrixQuadraticCoefficient,
    model,
)
    return print(
        io,
        "(Constraint -- Variable -- Variable): (",
        MathOptAnalyzer._name(issue.ref, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable1, model),
        " -- ",
        MathOptAnalyzer._name(issue.variable2, model),
        ") with coefficient ",
        issue.coefficient,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::NonconvexQuadraticObjective,
    model,
)
    return MathOptAnalyzer._summarize(io, issue, model)
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::NonconvexQuadraticConstraint,
    model,
)
    return print(io, "Constraint: ", MathOptAnalyzer._name(issue.ref, model))
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{VariableNotInConstraints},
)
    return data.variables_not_in_constraints
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{EmptyConstraint})
    return data.empty_rows
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{VariableBoundAsConstraint},
)
    return data.bound_rows
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{DenseConstraint})
    return data.dense_rows
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallMatrixCoefficient},
)
    return data.matrix_small
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeMatrixCoefficient},
)
    return data.matrix_large
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{SmallBoundCoefficient})
    return data.bounds_small
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{LargeBoundCoefficient})
    return data.bounds_large
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{SmallRHSCoefficient})
    return data.rhs_small
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{LargeRHSCoefficient})
    return data.rhs_large
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallObjectiveCoefficient},
)
    return data.objective_small
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeObjectiveCoefficient},
)
    return data.objective_large
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallObjectiveQuadraticCoefficient},
)
    return data.objective_quadratic_small
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeObjectiveQuadraticCoefficient},
)
    return data.objective_quadratic_large
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{SmallMatrixQuadraticCoefficient},
)
    return data.matrix_quadratic_small
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{LargeMatrixQuadraticCoefficient},
)
    return data.matrix_quadratic_large
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{NonconvexQuadraticObjective},
)
    return data.nonconvex_objective
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{NonconvexQuadraticConstraint},
)
    return data.nonconvex_rows
end

function MathOptAnalyzer.list_of_issue_types(data::Data)
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
        if !isempty(MathOptAnalyzer.list_of_issues(data, type))
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

function MathOptAnalyzer.summarize(
    io::IO,
    data::Data;
    model = nothing,
    verbose = true,
    max_issues = MathOptAnalyzer.DEFAULT_MAX_ISSUES,
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
    for issue_type in MathOptAnalyzer.list_of_issue_types(data)
        issues = MathOptAnalyzer.list_of_issues(data, issue_type)
        print(io, "\n\n")
        MathOptAnalyzer.summarize(
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
        length(MathOptAnalyzer.list_of_issues(data, T)) for
        T in MathOptAnalyzer.list_of_issue_types(data);
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
