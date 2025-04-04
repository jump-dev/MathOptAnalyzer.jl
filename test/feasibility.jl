# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestDualFeasibilityChecker

import ModelAnalyzer
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
    @test_throws ErrorException ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(),
    )
    # no dual solutions available
    @test_throws ErrorException ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
    )
    # non linear not accepted
    @constraint(model, c, x^4 >= 0) # this will make the model non-linear
    @test_throws ErrorException ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
    )
end

function test_only_bounds()
    # in this case the dual has no varaibles and has innocuous constraints
    # this needs to be reviewed in Dualization.jl
    model = Model()
    @variable(model, x >= 0)
    @objective(model, Min, x)
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(LowerBoundRef(x) => 1.0),
    )
    @test isempty(report)

    buf = IOBuffer()
    Base.show(buf, report)
    str = String(take!(buf))
    @test str == "Feasibility analysis found 0 issues"
end

function test_no_lb()
    model = Model()
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)
    # the dual is:
    # Max 0
    # Subject to
    # y == 1 (as a constraint) # from x, a free "bounded" varaible
    # y >= 0 (as a bound) # from c, a ">=" constraint
    # mayber force fail here
    # @test_throws ErrorException
    report =
        ModelAnalyzer.Feasibility.dual_feasibility_report(model, Dict(c => 1.0))
    @test isempty(report)
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [1.0]),
    )
    @test isempty(report)
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [3.3]),
    )
    @test report[x] == 2.3
    @test length(report) == 1
end

function test_lb0()
    model = Model()
    @variable(model, x >= 0)
    @constraint(model, c, x >= 0.5)
    @objective(model, Min, x)
    # the dual is:
    # Max 0.5 * y
    # Subject to
    # - y >= -1 (as a constraint) # from x >= 0 (bound)
    #   y >=  0 (as a bound) # from c, a ">=" constraint
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [1.0], LowerBoundRef(x) => [0.0]),
    )
    @test isempty(report)
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[LowerBoundRef(x)] == 2.3
    @test length(report) == 1
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [-3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[c] == 3.3
    @test length(report) == 1
end

function test_lb2()
    model = Model()
    @variable(model, x >= 2)
    @constraint(model, c, x >= 0.5)
    @objective(model, Min, x)
    # the dual is:
    # Max 0.5 * y + 2 * z
    # Subject to
    # y + z == 1 (as a constraint) # from x, a free variable (bound is considered below)
    # z >= 0     (as a bound) # from the "constraint" x >= 2 (bound in the above example)
    # y >= 0     (as a bound) # from c, a ">=" constraint
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [1.0], LowerBoundRef(x) => [0.0]),
    )
    @test isempty(report)
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[x] == 2.3
    @test length(report) == 1
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [-3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[x] == 4.3
    @test report[c] == 3.3
    @test length(report) == 2
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [-3.3], LowerBoundRef(x) => [-1.0]),
    )
    @test report[x] == 5.3
    @test report[c] == 3.3
    @test report[LowerBoundRef(x)] == 1.0
    @test length(report) == 3
    report = ModelAnalyzer.Feasibility.dual_feasibility_report(
        model,
        Dict(c => [-3.3]),
        skip_missing = true,
    )
    @test report[c] == 3.3
    @test length(report) == 1
end

function test_analyse_simple()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)

    optimize!(model)

    data = ModelAnalyzer.analyze(ModelAnalyzer.Feasibility.Analyzer(), model)

    list = ModelAnalyzer.list_of_issue_types(data)

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

    data = ModelAnalyzer.analyze(ModelAnalyzer.Feasibility.Analyzer(), model)

    list = ModelAnalyzer.list_of_issue_types(data)

    @test length(list) == 0

    ModelAnalyzer.summarize(data)

    return
end

function test_analyse_no_opt()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @constraint(model, c, x >= 0)
    @objective(model, Min, x)

    # test no primal point
    @test_throws ErrorException ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
    )

    # test no dual point
    @test_throws ErrorException ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(x => 1.0),
        dual_check = true,
    )

    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(x => 1.0),
        dual_check = false,
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 0

    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(x => -1.0),
        dual_check = false,
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test ret[] == ModelAnalyzer.Feasibility.PrimalViolation(c, 1.0)

    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(x => 1.0),
        dual_point = Dict(c => 1.0),
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 2
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test ret[1] == ModelAnalyzer.Feasibility.ComplemetarityViolation(c, 1.0)
    ret = ModelAnalyzer.list_of_issues(data, list[2])
    @test ret[1] == ModelAnalyzer.Feasibility.PrimalDualMismatch(1.0, 0.0)

    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(x => 0.0),
        dual_point = Dict(c => 1.0),
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 0

    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Feasibility.Analyzer(),
        model,
        primal_point = Dict(x => -1.0),
        dual_point = Dict(c => 2.0),
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 4
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test ret[1] == ModelAnalyzer.Feasibility.PrimalViolation(c, 1.0)
    ret = ModelAnalyzer.list_of_issues(data, list[2])
    @test ret[1] == ModelAnalyzer.Feasibility.DualViolation(x, 1.0)
    ret = ModelAnalyzer.list_of_issues(data, list[3])
    @test ret[1] == ModelAnalyzer.Feasibility.ComplemetarityViolation(c, -2.0)
    ret = ModelAnalyzer.list_of_issues(data, list[4])
    @test ret[1] == ModelAnalyzer.Feasibility.PrimalDualMismatch(-1.0, 0.0)

    ModelAnalyzer.summarize(data)

    ModelAnalyzer.summarize(data, verbose = false)

    return
end

# these tests are harder to permorm with a real solver as they tipically
# return coherent objectives
function test_lowlevel_mismatch()
    buf = IOBuffer()
    issues = []
    push!(issues, ModelAnalyzer.Feasibility.PrimalObjectiveMismatch(0.0, 1.0))
    push!(issues, ModelAnalyzer.Feasibility.DualObjectiveMismatch(0.0, 1.0))
    push!(issues, ModelAnalyzer.Feasibility.PrimalDualSolverMismatch(0.0, 1.0))
    for verbose in (true, false)
        ModelAnalyzer.summarize(
            buf,
            ModelAnalyzer.Feasibility.PrimalObjectiveMismatch,
            verbose = verbose,
        )
        ModelAnalyzer.summarize(
            buf,
            ModelAnalyzer.Feasibility.DualObjectiveMismatch,
            verbose = verbose,
        )
        ModelAnalyzer.summarize(
            buf,
            ModelAnalyzer.Feasibility.PrimalDualSolverMismatch,
            verbose = verbose,
        )
        for issue in issues
            # ensure we can summarize each issue type
            ModelAnalyzer.summarize(buf, issue, verbose = verbose)
        end
    end

    return
end

end # module

TestDualFeasibilityChecker.runtests()
