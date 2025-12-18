# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestNumerical

import MathOptAnalyzer
using Test
using JuMP

function runtests()
    for name in names(@__MODULE__; all = true)
        if startswith("$name", "test_")
            @testset "$(name)" begin
                getfield(@__MODULE__, name)()
            end
        end
    end
    return
end

function test_variable_bounds()
    model = Model()
    @variable(model, xg <= 2e9)
    @variable(model, xs <= 2e-9)
    @variable(model, ys >= 3e-10)
    @variable(model, yg >= 3e+10)
    @variable(model, zs == 4e-11)
    @variable(model, zg == 4e+11)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 4
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 6
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
    )
    @test length(ret) == 3
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
    )
    @test length(ret) == 3
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeBound,
    )
    @test length(ret) == 1

    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallBoundCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallBoundCoefficient"
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeBoundCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeBoundCoefficient"

    return
end

function test_constraint_bounds()
    model = Model()
    @variable(model, x)
    @constraint(model, x >= 2e+10)
    @constraint(model, x >= 2e-11)
    @constraint(model, x == 4e-12)
    @constraint(model, x == 4e+13)
    @constraint(model, x <= 1e-14)
    @constraint(model, x <= 1e+15)
    @constraint(model, [x] in MOI.Nonnegatives(1))
    @constraint(model, [x - 1e-16] in MOI.Nonnegatives(1))
    @constraint(model, [x - 1e+17] in MOI.Nonnegatives(1))
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 3
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    @test length(ret) == 6
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 4
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 4

    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallRHSCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallRHSCoefficient"
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeRHSCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeRHSCoefficient"

    return
end

function test_constraint_bounds_quad()
    model = Model()
    @variable(model, x)
    @constraint(model, x^2 <= 1e-14)
    @constraint(model, x^2 <= 1e+15)
    @constraint(model, [x^2 - 1e-16] in MOI.Nonpositives(1))
    @constraint(model, [x^2 - 1e+17] in MOI.Nonpositives(1))
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    @test length(ret) == 0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 2
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 2

    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallRHSCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallRHSCoefficient"
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeRHSCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeRHSCoefficient"

    return
end

function test_constraint_bounds_quad_vec()
    model = Model()
    @variable(model, x)
    @constraint(model, c, [-x^2 - 3] in MOI.Nonpositives(1))
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[]) == JuMP.index(c)
    return
end

function test_no_names()
    model = Model()
    set_string_names_on_creation(model, false)
    @variable(model, x)
    @variable(model, y)
    @constraint(model, 7y >= 3)
    @constraint(model, z, 0.0 * y == 3)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true, model = model)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    MathOptAnalyzer.summarize(
        buf,
        ret[1],
        verbose = true,
        model = JuMP.backend(model),
    )
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false, model = model)
    str = String(take!(buf))
    #
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.EmptyConstraint,
    )
    @test length(ret) == 1
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true, model = model)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(
        buf,
        ret[1],
        verbose = true,
        model = JuMP.backend(model),
    )
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false, model = model)
    str = String(take!(buf))
    return
end

function test_variable_not_in_constraints()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, 7y >= 3)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[]) == JuMP.index(x)
    @test MathOptAnalyzer.variable(ret[], model) == x
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true, model = model)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    MathOptAnalyzer.summarize(
        buf,
        ret[1],
        verbose = true,
        model = JuMP.backend(model),
    )
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false, model = model)
    str = String(take!(buf))
    return
end

function test_empty_constraint_model()
    model = Model()
    @variable(model, x)
    @constraint(model, c1, 2 * x == 5)
    @constraint(model, c2, 0.0 * x == 3)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.EmptyConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[]) == JuMP.index(c2)
    @test MathOptAnalyzer.constraint(ret[], model) == c2
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, MathOptAnalyzer.Numerical.EmptyConstraint)
    str = String(take!(buf))
    @test startswith(str, "# `EmptyConstraint`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.EmptyConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# EmptyConstraint"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true, model = model)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(
        buf,
        ret[1],
        verbose = true,
        model = JuMP.backend(model),
    )
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false, model = model)
    str = String(take!(buf))
    return
end

function test_variable_bound_as_constraint()
    model = Model()
    @variable(model, x)
    @constraint(model, c, x <= 2)
    @constraint(model, 3x <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[]) == JuMP.index(c)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    str = String(take!(buf))
    @test startswith(str, "# `VariableBoundAsConstraint`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.VariableBoundAsConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# VariableBoundAsConstraint"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    return
end

function test_dense_constraint()
    model = Model()
    @variable(model, x[1:10_000] <= 1)
    @constraint(model, c, sum(x) <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.DenseConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[]) == JuMP.index(c)
    @test MathOptAnalyzer.constraint(ret[], JuMP.backend(model)) ==
          JuMP.index(c)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 10_000
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, MathOptAnalyzer.Numerical.DenseConstraint)
    str = String(take!(buf))
    @test startswith(str, "# `DenseConstraint`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.DenseConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# DenseConstraint"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_matrix_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, 1e-9 * x <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallMatrixCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.variable(ret[], JuMP.backend(model)) == JuMP.index(x)
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallMatrixCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallMatrixCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallMatrixCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallMatrixCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable): (")
    @test contains(str, ") with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_large_matrix_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, 1e+9 * x <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeMatrixCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e+9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeMatrixCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeMatrixCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeMatrixCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeMatrixCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable): (")
    @test contains(str, ") with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_small_bound_coef()
    model = Model()
    @variable(model, x <= 1e-9)
    @constraint(model, 3 * x <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallBoundCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallBoundCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with bound ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_large_bound_coef()
    model = Model()
    @variable(model, x <= 1e+9)
    @constraint(model, 3 * x <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e+9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeBoundCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeBoundCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with bound ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_rhs_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, 3 * x <= 1e-9)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallRHSCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallRHSCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with right-hand-side ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_large_rhs_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, 3 * x <= 1e+9)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 1e+9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeRHSCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeRHSCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with right-hand-side ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_objective_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e-9 * x)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallObjectiveCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallObjectiveCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallObjectiveCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallObjectiveCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallObjectiveCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_large_objective_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e+9 * x)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeObjectiveCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e+9
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeObjectiveCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeObjectiveCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeObjectiveCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeObjectiveCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_objective_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e-9 * x^2)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, x]
    @test MathOptAnalyzer.variables(ret[], JuMP.backend(model)) ==
          JuMP.index.([x, x])
    @test_broken MathOptAnalyzer.value(ret[]) == 1e-9 # 2e-9 TODO, what to return here
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallObjectiveQuadraticCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallObjectiveQuadraticCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Variable -- Variable): (")
    @test contains(str, " with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_large_objective_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e+9 * x^2)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, x]
    @test_broken MathOptAnalyzer.value(ret[]) == 1e+9 # 2e+9 TODO, what to return here
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeObjectiveQuadraticCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeObjectiveQuadraticCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Variable -- Variable): (")
    @test contains(str, " with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_small_matrix_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, 1e-9 * x^2 + x <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, x]
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test_broken MathOptAnalyzer.value(ret[]) == 1e-9 # 2e-9 TODO, what to return here
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallMatrixQuadraticCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallMatrixQuadraticCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable -- Variable): (")
    @test contains(str, ") with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_large_matrix_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, 1e+9 * x^2 <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, x]
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test_broken MathOptAnalyzer.value(ret[]) == 1e+9 # 2e+9 TODO, what to return here
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeMatrixQuadraticCoefficient`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeMatrixQuadraticCoefficient"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable -- Variable): (")
    @test contains(str, ") with coefficient ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_objective_nonconvex()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Max, x^2)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    str = String(take!(buf))
    @test startswith(str, "# `NonconvexQuadraticObjective`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.NonconvexQuadraticObjective,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# NonconvexQuadraticObjective"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    return
end

function test_objective_nonconvex_2()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, -x^2)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    str = String(take!(buf))
    @test startswith(str, "# `NonconvexQuadraticObjective`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.NonconvexQuadraticObjective,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# NonconvexQuadraticObjective"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    return
end

function test_constraint_nonconvex()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, c, x^2 >= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint,
    )
    str = String(take!(buf))
    @test startswith(str, "# `NonconvexQuadraticConstraint`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# NonconvexQuadraticConstraint"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    return
end

function test_empty_model()
    model = Model()
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_nonconvex_zeros()
    model = Model()
    @variable(model, x[1:1])
    @constraint(model, c, [x[1] * x[1]] in Zeros())
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.NonconvexQuadraticConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    return
end

function test_vi_in_nonstandard_set()
    model = Model()
    @variable(model, x[1:1])
    @constraint(model, c, x[1] in MOI.ZeroOne())
    @constraint(model, c1, 3x[1] + 1e-9 in MOI.ZeroOne())
    @constraint(model, c2, 4x[1] - 1e+9 in MOI.ZeroOne())
    @constraint(model, c3, 2x[1] == 0)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c1
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c2
    @test MathOptAnalyzer.value(ret[]) == -1e+9
    return
end

function test_saf_in_nonstandard_set()
    model = Model()
    @variable(model, x[1:1])
    @constraint(model, c, 2x[1] in MOI.ZeroOne())
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_vaf_in_nonstandard_set()
    model = Model()
    @variable(model, x[1:1])
    @constraint(model, c, [2x[1], x[1], x[1]] in SecondOrderCone())
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_vector_functions()
    model = Model()
    @variable(model, x[1:3])
    @constraint(model, c1, [1e-9 * x[1]] in Nonnegatives())
    @constraint(model, c2, [1e+9 * x[1]] in Nonnegatives())
    @constraint(model, c3, [x[2], x[1]] in Nonnegatives())
    @constraint(model, c4, [-1e-9 * x[1] * x[1]] in Nonnegatives())
    @constraint(model, c5, [1e+9 * x[1] * x[1]] in Nonnegatives())
    @constraint(model, c6, [2 * x[1] * x[1]] in Zeros())
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 8
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallMatrixCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c1
    @test MathOptAnalyzer.variable(ret[], model) == x[1]
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeMatrixCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c2
    @test MathOptAnalyzer.variable(ret[], model) == x[1]
    @test MathOptAnalyzer.value(ret[]) == 1e+9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c4
    @test MathOptAnalyzer.variables(ret[], model) == [x[1], x[1]]
    @test_broken MathOptAnalyzer.value(ret[]) == 1e-9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c5
    @test MathOptAnalyzer.variables(ret[], model) == [x[1], x[1]]
    @test_broken MathOptAnalyzer.value(ret[]) == 1e+9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x[3]
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x[1], x[1]]
    @test MathOptAnalyzer.values(ret[]) == [1e-9, 1e+9]
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeVariable,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x[1]
    @test MathOptAnalyzer.constraints(ret[], model) == [c1, c2]
    @test MathOptAnalyzer.values(ret[]) == [1e-9, 1e+9]
    return
end

function test_variable_interval()
    model = Model()
    @variable(model, x in MOI.Interval(1e-9, 1e+9))
    @objective(model, Min, x)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 4
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.SmallBoundCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e-9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 1e+9
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeBound,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, x]
    return
end

function test_many()
    model = Model()
    @variable(model, x <= 2e9)
    @variable(model, y >= 3e-9)
    @variable(model, z == 4e-9)
    @variable(model, w[1:1] in MOI.Nonnegatives(1))
    @variable(model, u[1:1])
    @variable(model, v[1:1])
    @constraint(model, x + y <= 4e8)
    @constraint(model, x + y + 5e7 <= 2)
    @constraint(model, 7e6 * x + 6e-15 * y + 2e-12 >= 0)
    @constraint(model, x <= 100)
    @constraint(model, x <= 1e-17)
    @constraint(model, x >= 1e+18)
    @constraint(model, x == 1e+19)
    @constraint(model, x == 1e-20)
    @constraint(model, 0 * x == 0)
    @constraint(model, 1e-21 <= x <= 1e-22)
    @constraint(model, 1e+23 <= x <= 1e+24)
    @constraint(model, [1.0 * x] in MOI.Nonnegatives(1))
    @constraint(model, [1.0 * x * x] in MOI.Nonnegatives(1))
    @constraint(model, u in MOI.Nonnegatives(1))
    @constraint(model, v in MOI.PositiveSemidefiniteConeTriangle(1))
    @constraint(model, [v[] - 1.0] in MOI.PositiveSemidefiniteConeTriangle(1))

    @objective(model, Max, 1e8 * x + 8e-11 * y)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))

    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data)
    MathOptAnalyzer.summarize(buf, data, verbose = false)

    redirect_stdout(devnull) do
        MathOptAnalyzer.summarize(data)
        list = MathOptAnalyzer.list_of_issue_types(data)
        MathOptAnalyzer.summarize(list[1])
        issues = MathOptAnalyzer.list_of_issues(data, list[1])
        MathOptAnalyzer.summarize(issues)
        MathOptAnalyzer.summarize(issues[1])
        return
    end

    return
end

function test_nonconvex_qp()
    model = Model()
    @variable(model, x <= 1)
    @variable(model, y >= 3)
    @constraint(model, -x * x <= 4) # bad 1
    @constraint(model, +x * x <= 4)
    @constraint(model, -x * x == 4) # bad 2
    @constraint(model, +x * x == 4) # bad 3
    @constraint(model, -x * x >= 4)
    @constraint(model, +x * x >= 4) # bad 4
    @constraint(model, x * y <= 4) # bad 5
    @constraint(model, x * y == 4) # bad 6
    @constraint(model, x * y >= 4) # bad 7
    @objective(model, Max, y * x)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))

    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data)
    MathOptAnalyzer.summarize(buf, data, verbose = false)

    return
end

function test_qp_range()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c, 1e-7 * x^2 + 7e8 * y * y <= 4)
    @objective(model, Min, 3e-7 * x * x + 2e12 * y * y)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))

    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data)
    MathOptAnalyzer.summarize(buf, data, verbose = false)

    open("my_report.txt", "w") do io
        return MathOptAnalyzer.summarize(io, data)
    end

    file_data = read("my_report.txt", String)
    @test occursin("## Numerical Analysis", file_data)

    return
end

function test_more_than_max_issues()
    model = Model()
    @variable(model, xg[1:20] <= 2e9)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) >= 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeBoundCoefficient,
    )
    @test length(ret) == 20

    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data)
    str = String(take!(buf))
    @test occursin("Showing first ", str)
    @test occursin(" issues ommitted)\n\n", str)

    return
end

function test_dyn_range_constraint_and_matrix()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c, 1e-4 * x + 7e4 * y <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeConstraint,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.variables(ret[], model) == [x, y]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeConstraint,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeConstraint`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeConstraint"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with dynamic range ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    @test contains(str, ", [")
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, y]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeMatrix`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeMatrix"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Matrix dynamic range")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, "[")
    return
end

function test_dyn_range_variable_and_matrix()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c1, 1e-4 * x + y <= 4)
    @constraint(model, c2, 7e4 * x + y <= 4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeVariable,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.constraints(ret[], model) == [c1, c2]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeVariable,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeVariable`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeVariable,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeVariable"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable:")
    @test contains(str, " with dynamic range ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    @test contains(str, ", [")
    #
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, x]
    @test MathOptAnalyzer.constraints(ret[], model) == [c1, c2]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeMatrix`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeMatrix,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeMatrix"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Matrix dynamic range")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, "[")
    return
end

function test_dyn_range_objective()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c1, 1 * x + y <= 4)
    @constraint(model, c2, 2 * x + y <= 4)
    @objective(model, Min, 1e-4 * x + 7e4 * y)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeObjective,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, y]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeObjective,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeObjective`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeObjective,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeObjective"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Objective dynamic range")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, "[")
    return
end

function test_dyn_range_rhs()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c1, x + y <= 1e-4)
    @constraint(model, c2, x + y <= 7e4)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeRHS,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.constraints(ret[], model) == [c1, c2]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeRHS,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeRHS`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeRHS,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeRHS"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "RHS dynamic range:")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    @test contains(str, ", [")
    return
end

function test_dyn_range_bounds()
    model = Model()
    @variable(model, x <= 1e-4)
    @variable(model, y >= 7e4)
    @constraint(model, c1, x + y <= 4)
    @constraint(model, c2, x - y >= 3)
    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Numerical.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Numerical.LargeDynamicRangeBound,
    )
    @test length(ret) == 1
    @test MathOptAnalyzer.variables(ret[], model) == [x, y]
    @test MathOptAnalyzer.values(ret[]) == [1e-4, 7e4]
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeBound,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeDynamicRangeBound`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Numerical.LargeDynamicRangeBound,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeDynamicRangeBound"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Bounds with dynamic range:")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    @test contains(str, ", [")
    return
end

end  # module TestNumerical

TestNumerical.runtests()
