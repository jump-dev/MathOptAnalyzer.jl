# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestFeasibility

using MathOptAnalyzer
using Test
using JuMP
import HiGHS

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

function test_no_solution()
    model = Model()
    @variable(model, x, Bin)
    # do not support binary
    @test_throws "No primal" MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
    )
    # no dual solutions available
    # @test_throws ErrorException
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        # dual_point = Dict(),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)
    # non linear in primal accepted
    @constraint(model, c, x^4 >= 0) # this will make the model non-linear
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)
end

function test_only_bounds()
    model = Model()
    @variable(model, x >= 0)
    @objective(model, Min, x)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(LowerBoundRef(x)) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => -1.0),
        dual_point = Dict(JuMP.index(LowerBoundRef(x)) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == Type[
        MathOptAnalyzer.Feasibility.PrimalViolation,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalViolation(
        JuMP.index(LowerBoundRef(x)),
        1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.ComplemetarityViolation(
        JuMP.index(LowerBoundRef(x)),
        -1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[]) == -1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(-1.0, 0.0)
    @test MathOptAnalyzer.values(ret[]) == [-1.0, 0.0]

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(JuMP.index(LowerBoundRef(x)) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.ComplemetarityViolation(
        JuMP.index(LowerBoundRef(x)),
        1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(1.0, 0.0)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(JuMP.index(LowerBoundRef(x)) => -1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 2.0)
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 2.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(LowerBoundRef(x)),
        1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.ComplemetarityViolation(
        JuMP.index(LowerBoundRef(x)),
        -1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[]) == -1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(1.0, 0.0)
    return
end

function test_no_lb()
    model = Model()
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)
    # the dual is:
    # Max 0
    # Subject to
    # y == 1 (as a constraint)
    # y >= 0 (as a bound)
    # mayber force fail here
    # @test_throws ErrorException

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => -1.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == Type[
        MathOptAnalyzer.Feasibility.PrimalViolation,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalViolation(JuMP.index(c), 1.0)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.ComplemetarityViolation(JuMP.index(c), -1.0)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == -1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(-1.0, 0.0)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.ComplemetarityViolation(JuMP.index(c), 1.0)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(1.0, 0.0)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(JuMP.index(c) => -1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 2.0)
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 2.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(c),
        1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.ComplemetarityViolation(JuMP.index(c), -1.0)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == -1.0
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(1.0, 0.0)
end

function test_lb0()
    model = Model()
    @variable(model, x >= 0)
    @constraint(model, c, x >= 0.5)
    @objective(model, Min, x)
    # the dual is:
    # Max 0.5 * y
    # Subject to
    # ...
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.5),
        dual_point = Dict(
            JuMP.index(c) => 1.0,
            JuMP.index(LowerBoundRef(x)) => 0.0,
        ),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.5),
        dual_point = Dict(
            JuMP.index(c) => 3.3,
            JuMP.index(LowerBoundRef(x)) => 0.0,
        ),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 2.3)
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 2.3

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.5),
        dual_point = Dict(
            JuMP.index(c) => -3.3,
            JuMP.index(LowerBoundRef(x)) => 0.0,
        ),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 4.3)
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 4.3
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(c),
        3.3,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 3.3
    return
end

function test_lb2()
    model = Model()
    @variable(model, x >= 2)
    @constraint(model, c, x >= 0.5)
    @objective(model, Min, x)
    # the dual is:
    # Max 0.5 * y + 2 * z
    # Subject to
    # ...

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(
            JuMP.index(c) => 0.0,
            JuMP.index(LowerBoundRef(x)) => 1.0,
        ),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test isempty(list)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(
            JuMP.index(c) => 3.3,
            JuMP.index(LowerBoundRef(x)) => 0.0,
        ),
    )
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 2.3)
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.value(ret[]) == 2.3

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(
            JuMP.index(c) => -3.3,
            JuMP.index(LowerBoundRef(x)) => 0.0,
        ),
    )
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 4.3)
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(c),
        3.3,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 3.3

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(
            JuMP.index(c) => -3.3,
            JuMP.index(LowerBoundRef(x)) => -1.0,
        ),
    )
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
    )
    @test ret[] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 5.3)
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[1] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(c),
        3.3,
    )
    @test MathOptAnalyzer.constraint(ret[1], model) == c
    @test MathOptAnalyzer.value(ret[1]) == 3.3
    @test ret[2] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(LowerBoundRef(x)),
        1.0,
    )
    @test MathOptAnalyzer.constraint(ret[2], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[2]) == 1.0

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(
            JuMP.index(c) => -3.3,
            # JuMP.index(LowerBoundRef(x)) => -1.0,
        ),
        skip_missing = true,
    )

    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(c),
        3.3,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 3.3
    return
end

function test_analyse_simple()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)

    optimize!(model)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Feasibility.Analyzer(), model)

    list = MathOptAnalyzer.list_of_issue_types(data)

    @test length(list) == 0

    return
end

function test_analyse_simple_direct()
    model = direct_model(HiGHS.Optimizer())
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, 2 * x)

    optimize!(model)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Feasibility.Analyzer(), model)

    list = MathOptAnalyzer.list_of_issue_types(data)

    @test length(list) == 0

    return
end

function test_with_interval()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x >= 1)
    @constraint(model, c, 2 * x in MOI.Interval(0.0, 3.0))
    @objective(model, Min, x)
    optimize!(model)
    @test !MathOptAnalyzer.Feasibility._can_dualize(JuMP.backend(model))
    return
end

function test_analyse_many_constraint_types()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x >= 1)
    @variable(model, y <= 0)
    @variable(model, z == 0)
    @variable(model, w)
    @variable(model, 0 <= v <= 1)
    @constraint(model, c1, x >= 0)
    @constraint(model, c2, x <= 10)
    @constraint(model, c3, x == 5)
    @constraint(model, c4, y >= -1)
    @constraint(model, c5, w == 3)
    @constraint(model, c6, [2v] in Nonpositives()) # this should be redundant as z is fixed to 0
    @objective(model, Min, x)

    optimize!(model)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Feasibility.Analyzer(), model)

    list = MathOptAnalyzer.list_of_issue_types(data)

    @test length(list) == 0

    return
end

function test_analyse_mip()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x, Bin)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)

    optimize!(model)

    data = MathOptAnalyzer.analyze(MathOptAnalyzer.Feasibility.Analyzer(), model)

    list = MathOptAnalyzer.list_of_issue_types(data)

    @test length(list) == 0

    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data)

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))
    @test str == "Feasibility analysis found 0 issues"

    return
end

function test_analyse_no_opt()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)

    # test no primal point
    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
    )

    # test no dual point
    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_check = true,
    )

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_check = false,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => -1.0),
        dual_check = false,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test ret[] == MathOptAnalyzer.Feasibility.PrimalViolation(JuMP.index(c), 1.0)
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.value(ret[]) == 1.0

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test ret[1] ==
          MathOptAnalyzer.Feasibility.ComplemetarityViolation(JuMP.index(c), 1.0)
    @test MathOptAnalyzer.constraint(ret[1], model) == c
    @test MathOptAnalyzer.value(ret[1]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(data, list[2])
    @test ret[1] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(1.0, 0.0)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => -1.0),
        dual_point = Dict(JuMP.index(c) => 2.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 4
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test ret[1] ==
          MathOptAnalyzer.Feasibility.PrimalViolation(JuMP.index(c), 1.0)
    @test MathOptAnalyzer.constraint(ret[1], model) == c
    @test MathOptAnalyzer.value(ret[1]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(data, list[2])
    @test ret[1] ==
          MathOptAnalyzer.Feasibility.DualConstraintViolation(JuMP.index(x), 1.0)
    @test MathOptAnalyzer.variable(ret[1], model) == x
    @test MathOptAnalyzer.value(ret[1]) == 1.0
    ret = MathOptAnalyzer.list_of_issues(data, list[3])
    @test ret[1] ==
          MathOptAnalyzer.Feasibility.ComplemetarityViolation(JuMP.index(c), -2.0)
    @test MathOptAnalyzer.constraint(ret[1], model) == c
    @test MathOptAnalyzer.value(ret[1]) == -2.0
    ret = MathOptAnalyzer.list_of_issues(data, list[4])
    @test ret[1] == MathOptAnalyzer.Feasibility.PrimalDualMismatch(-1.0, 0.0)

    buf = IOBuffer()

    MathOptAnalyzer.summarize(buf, data)

    MathOptAnalyzer.summarize(buf, data, verbose = false)

    return
end

function test_dual_constrained_variable()
    model = Model()
    @variable(model, x >= 0)
    @objective(model, Min, x)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        dual_point = Dict(JuMP.index(LowerBoundRef(x)) => -1.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test list == [
        MathOptAnalyzer.Feasibility.DualConstraintViolation,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
        MathOptAnalyzer.Feasibility.ComplemetarityViolation,
        MathOptAnalyzer.Feasibility.PrimalDualMismatch,
    ]
    ret = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
    )
    @test ret[] == MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation(
        JuMP.index(LowerBoundRef(x)),
        1.0,
    )
    @test MathOptAnalyzer.constraint(ret[], model) == LowerBoundRef(x)
    @test MathOptAnalyzer.value(ret[]) == 1.0

    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
        verbose = true,
    )
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Feasibility.DualConstrainedVariableViolation,
        verbose = false,
    )
    MathOptAnalyzer.summarize(buf, ret[], verbose = true)
    MathOptAnalyzer.summarize(buf, ret[], verbose = false)
    return
end

# these tests are harder to permorm with a real solver as they tipically
# return coherent objectives
function test_lowlevel_mismatch()
    buf = IOBuffer()
    issues = []
    push!(issues, MathOptAnalyzer.Feasibility.PrimalObjectiveMismatch(0.0, 1.0))
    push!(issues, MathOptAnalyzer.Feasibility.DualObjectiveMismatch(0.0, 1.0))
    push!(issues, MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch(0.0, 1.0))
    for verbose in (true, false)
        MathOptAnalyzer.summarize(
            buf,
            MathOptAnalyzer.Feasibility.PrimalObjectiveMismatch,
            verbose = verbose,
        )
        MathOptAnalyzer.summarize(
            buf,
            MathOptAnalyzer.Feasibility.DualObjectiveMismatch,
            verbose = verbose,
        )
        MathOptAnalyzer.summarize(
            buf,
            MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch,
            verbose = verbose,
        )
        for issue in issues
            # ensure we can summarize each issue type
            MathOptAnalyzer.summarize(buf, issue, verbose = verbose)
        end
    end

    return
end

function test_skip_missing_primal()
    model = Model()
    set_silent(model)
    @variable(model, x >= 0)
    @variable(model, y >= 0)
    @constraint(model, c, x + y >= 0)
    @objective(model, Min, x)

    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        # dual_point = Dict(JuMP.index(c) => 1.0),
        skip_missing = false,
        dual_check = false,
    )
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 1.0),
        # dual_point = Dict(JuMP.index(c) => 1.0),
        skip_missing = true,
        dual_check = false,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(y) => 1.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
        skip_missing = true,
        dual_check = true,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_skip_missing_primal_var_not_in_con()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x + y)

    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        # dual_point = Dict(JuMP.index(c) => 1.0),
        skip_missing = false,
        dual_check = false,
    )
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        # dual_point = Dict(JuMP.index(c) => 1.0),
        skip_missing = true,
        dual_check = false,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_skip_missing_primal_empty_con()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, 1 >= 0)
    @constraint(model, c2, x >= 0)
    @objective(model, Min, x)

    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c2) => 1.0),
        skip_missing = false,
        dual_check = true,
    )
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c2) => 1.0),
        skip_missing = true,
        dual_check = true,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_skip_missing_dual()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c1, x >= 0)
    @constraint(model, c2, x >= 2)
    @objective(model, Min, x)

    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(JuMP.index(c1) => 1.0),
        skip_missing = false,
        dual_check = true,
    )
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(JuMP.index(c1) => 0.0),
        skip_missing = true,
        dual_check = true,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_dual_bad_size()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c1, x >= 0)
    @objective(model, Min, x)

    @test_throws ErrorException MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 2.0),
        dual_point = Dict(JuMP.index(c1) => [1.0, 2.0]),
    )
    return
end

function test_dual_vector()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c1, [x, 2x - 1] in Nonnegatives())
    @objective(model, Min, x)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.5),
        dual_point = Dict(JuMP.index(c1) => [0.0, 0.5]),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_feasibility_sense()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c1, x >= 0)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        # dual_point = Dict(JuMP.index(c1) => [0.0, 0.5]),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_objective()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
        primal_objective = 0.0,
        dual_objective = 0.0,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
        primal_objective = 1.0,
        dual_objective = 0.0,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    @test MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalObjectiveMismatch,
    )[] == MathOptAnalyzer.Feasibility.PrimalObjectiveMismatch(0.0, 1.0)
    @test MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch,
    )[] == MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch(1.0, 0.0)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c) => 1.0),
        primal_objective = 0.0,
        dual_objective = 1.0,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    @test MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.DualObjectiveMismatch,
    )[] == MathOptAnalyzer.Feasibility.DualObjectiveMismatch(0.0, 1.0)
    @test MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch,
    )[] == MathOptAnalyzer.Feasibility.PrimalDualSolverMismatch(0.0, 1.0)
    return
end

function test_nl_con()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c1, x^3 == 0)
    @objective(model, Min, x)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c1) => 0.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_nl_obj()
    model = Model()
    set_silent(model)
    @variable(model, x)
    @constraint(model, c1, x == 0)
    @objective(model, Min, x^3)

    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(JuMP.index(x) => 0.0),
        dual_point = Dict(JuMP.index(c1) => 0.0),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

end  # module TestFeasibility

TestFeasibility.runtests()
