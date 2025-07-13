# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function MathOptAnalyzer._summarize(io::IO, ::Type{<:InfeasibleBounds})
    return print(io, "# InfeasibleBounds")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{<:InfeasibleIntegrality})
    return print(io, "# InfeasibleIntegrality")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{<:InfeasibleConstraintRange})
    return print(io, "# InfeasibleConstraintRange")
end

function MathOptAnalyzer._summarize(io::IO, ::Type{<:IrreducibleInfeasibleSubset})
    return print(io, "# IrreducibleInfeasibleSubset")
end

function MathOptAnalyzer._verbose_summarize(io::IO, ::Type{<:InfeasibleBounds})
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._verbose_summarize(
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

function MathOptAnalyzer._summarize(io::IO, issue::InfeasibleBounds, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable, model),
        " : ",
        issue.lb,
        " !<= ",
        issue.ub,
    )
end

function MathOptAnalyzer._summarize(io::IO, issue::InfeasibleIntegrality, model)
    return print(
        io,
        MathOptAnalyzer._name(issue.variable, model),
        " : [",
        issue.lb,
        "; ",
        issue.ub,
        "], ",
        issue.set,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::InfeasibleConstraintRange,
    model,
)
    return print(
        io,
        MathOptAnalyzer._name(issue.constraint, model),
        " : [",
        issue.lb,
        "; ",
        issue.ub,
        "], !in ",
        issue.set,
    )
end

function MathOptAnalyzer._summarize(
    io::IO,
    issue::IrreducibleInfeasibleSubset,
    model,
)
    return print(
        io,
        "IIS: ",
        join(map(x -> MathOptAnalyzer._name(x, model), issue.constraint), ", "),
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleBounds,
    model,
)
    return print(
        io,
        "Variable: ",
        MathOptAnalyzer._name(issue.variable, model),
        " with lower bound ",
        issue.lb,
        " and upper bound ",
        issue.ub,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleIntegrality,
    model,
)
    return print(
        io,
        "Variable: ",
        MathOptAnalyzer._name(issue.variable, model),
        " with lower bound ",
        issue.lb,
        " and upper bound ",
        issue.ub,
        " and integrality constraint: ",
        issue.set,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::InfeasibleConstraintRange,
    model,
)
    return print(
        io,
        "Constraint: ",
        MathOptAnalyzer._name(issue.constraint, model),
        " with computed lower bound ",
        issue.lb,
        " and computed upper bound ",
        issue.ub,
        " and set: ",
        issue.set,
    )
end

function MathOptAnalyzer._verbose_summarize(
    io::IO,
    issue::IrreducibleInfeasibleSubset,
    model,
)
    print(io, "Irreducible Infeasible Subset: ")
    for constraint in issue.constraint
        println(io)
        print(io, "   ")
        print(io, MathOptAnalyzer._show(constraint, model))
    end
    return
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{InfeasibleBounds})
    return data.infeasible_bounds
end

function MathOptAnalyzer.list_of_issues(data::Data, ::Type{InfeasibleIntegrality})
    return data.infeasible_integrality
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{InfeasibleConstraintRange},
)
    return data.constraint_range
end

function MathOptAnalyzer.list_of_issues(
    data::Data,
    ::Type{IrreducibleInfeasibleSubset},
)
    return data.iis
end

function MathOptAnalyzer.list_of_issue_types(data::Data)
    ret = Type[]
    for type in (
        InfeasibleBounds,
        InfeasibleIntegrality,
        InfeasibleConstraintRange,
        IrreducibleInfeasibleSubset,
    )
        if !isempty(MathOptAnalyzer.list_of_issues(data, type))
            push!(ret, type)
        end
    end
    return ret
end

function MathOptAnalyzer.summarize(
    io::IO,
    data::Data;
    model = nothing,
    verbose = true,
    max_issues = MathOptAnalyzer.DEFAULT_MAX_ISSUES,
)
    print(io, "## Infeasibility Analysis\n\n")

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
    return print(io, "Infeasibility analysis found $n issues")
end
