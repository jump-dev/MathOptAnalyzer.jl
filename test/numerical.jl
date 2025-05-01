# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestNumerical

import ModelAnalyzer
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
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 3
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 6
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallBoundCoefficient,
    )
    @test length(ret) == 3
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeBoundCoefficient,
    )
    @test length(ret) == 3

    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.SmallBoundCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `SmallBoundCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallBoundCoefficient"
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.LargeBoundCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `LargeBoundCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeBoundCoefficient,
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
    @constraint(model, [x - 1e-16] in MOI.Nonnegatives(1))
    @constraint(model, [x - 1e+17] in MOI.Nonnegatives(1))
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 4
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    @test length(ret) == 8
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 4
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 4

    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.SmallRHSCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `SmallRHSCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallRHSCoefficient"
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.LargeRHSCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `LargeRHSCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeRHSCoefficient,
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
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    @test length(ret) == 0
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 0
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 2
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 2

    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.SmallRHSCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `SmallRHSCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallRHSCoefficient"
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.LargeRHSCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `LargeRHSCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeRHSCoefficient"

    return
end

function test_variable_not_in_constraints()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, 7y >= 3)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableNotInConstraints,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.VariableNotInConstraints,
    )
    str = String(take!(buf))
    @test startswith(str, "# `VariableNotInConstraints`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.VariableNotInConstraints,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# VariableNotInConstraints"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    return
end

function test_empty_constraint_model()
    model = Model()
    @variable(model, x)
    @constraint(model, 2 * x == 5)
    @constraint(model, 0.0 * x == 3)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.EmptyConstraint,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.EmptyConstraint)
    str = String(take!(buf))
    @test startswith(str, "# `EmptyConstraint`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.EmptyConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# EmptyConstraint"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    return
end

function test_variable_bound_as_constraint()
    model = Model()
    @variable(model, x)
    @constraint(model, x <= 2)
    @constraint(model, 3x <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.VariableBoundAsConstraint,
    )
    str = String(take!(buf))
    @test startswith(str, "# `VariableBoundAsConstraint`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.VariableBoundAsConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# VariableBoundAsConstraint"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    return
end

function test_dense_constraint()
    model = Model()
    @variable(model, x[1:10_000] <= 1)
    @constraint(model, sum(x) <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.DenseConstraint,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.DenseConstraint)
    str = String(take!(buf))
    @test startswith(str, "# `DenseConstraint`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.DenseConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# DenseConstraint"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_matrix_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 1e-9 * x <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallMatrixCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.SmallMatrixCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `SmallMatrixCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallMatrixCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallMatrixCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable): (")
    @test contains(str, ") with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_large_matrix_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 1e+9 * x <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeMatrixCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.LargeMatrixCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `LargeMatrixCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeMatrixCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeMatrixCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable): (")
    @test contains(str, ") with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_small_bound_coef()
    model = Model()
    @variable(model, x <= 1e-9)
    @constraint(model, 3 * x <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallBoundCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.SmallBoundCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `SmallBoundCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallBoundCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with bound ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_large_bound_coef()
    model = Model()
    @variable(model, x <= 1e+9)
    @constraint(model, 3 * x <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeBoundCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.LargeBoundCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `LargeBoundCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeBoundCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeBoundCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with bound ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_rhs_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 1e-9)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallRHSCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.SmallRHSCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `SmallRHSCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallRHSCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with right-hand-side ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_large_rhs_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 1e+9)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeRHSCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, ModelAnalyzer.Numerical.LargeRHSCoefficient)
    str = String(take!(buf))
    @test startswith(str, "# `LargeRHSCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeRHSCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeRHSCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with right-hand-side ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_objective_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e-9 * x)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallObjectiveCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallObjectiveCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallObjectiveCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallObjectiveCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallObjectiveCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_large_objective_coef()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e+9 * x)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeObjectiveCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeObjectiveCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeObjectiveCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeObjectiveCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeObjectiveCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    return
end

function test_small_objective_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, 1e-9 * x^2)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallObjectiveQuadraticCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallObjectiveQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallObjectiveQuadraticCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Variable -- Variable): (")
    @test contains(str, " with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
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
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeObjectiveQuadraticCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeObjectiveQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeObjectiveQuadraticCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Variable -- Variable): (")
    @test contains(str, " with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_small_matrix_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 1e-9 * x^2 + x <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `SmallMatrixQuadraticCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.SmallMatrixQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# SmallMatrixQuadraticCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable -- Variable): (")
    @test contains(str, ") with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " -- ")
    @test contains(str, " : ")
    return
end

function test_large_matrix_coef_quad()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 1e+9 * x^2 <= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
    )
    str = String(take!(buf))
    @test startswith(str, "# `LargeMatrixQuadraticCoefficient`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.LargeMatrixQuadraticCoefficient,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# LargeMatrixQuadraticCoefficient"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "(Constraint -- Variable -- Variable): (")
    @test contains(str, ") with coefficient ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
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
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    str = String(take!(buf))
    @test startswith(str, "# `NonconvexQuadraticObjective`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.NonconvexQuadraticObjective,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# NonconvexQuadraticObjective"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    return
end

function test_objective_nonconvex_2()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, 3 * x <= 4)
    @objective(model, Min, -x^2)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.NonconvexQuadraticObjective,
    )
    str = String(take!(buf))
    @test startswith(str, "# `NonconvexQuadraticObjective`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.NonconvexQuadraticObjective,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# NonconvexQuadraticObjective"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test startswith(str, "Objective is Nonconvex quadratic")
    return
end

function test_constraint_nonconvex()
    model = Model()
    @variable(model, x <= 1)
    @constraint(model, x^2 >= 4)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(
        data,
        ModelAnalyzer.Numerical.NonconvexQuadraticConstraint,
    )
    @test length(ret) == 1
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.NonconvexQuadraticConstraint,
    )
    str = String(take!(buf))
    @test startswith(str, "# `NonconvexQuadraticConstraint`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Numerical.NonconvexQuadraticConstraint,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# NonconvexQuadraticConstraint"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    return
end

function test_empty_model()
    model = Model()
    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

# TODO, test SDP and empty model

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

    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))

    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, data)
    ModelAnalyzer.summarize(buf, data, verbose = false)

    redirect_stdout(devnull) do
        return ModelAnalyzer.summarize(data)
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

    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))

    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, data)
    ModelAnalyzer.summarize(buf, data, verbose = false)

    return
end

function test_qp_range()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c, 1e-7 * x^2 + 7e8 * y * y <= 4)
    @objective(model, Min, 3e-7 * x * x + 2e12 * y * y)

    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))

    buf = IOBuffer()
    ModelAnalyzer.summarize(buf, data)
    ModelAnalyzer.summarize(buf, data, verbose = false)

    open("my_report.txt", "w") do io
        return ModelAnalyzer.summarize(io, data)
    end

    file_data = read("my_report.txt", String)
    @test occursin("## Numerical Analysis", file_data)

    return
end

end  # module

TestNumerical.runtests()
