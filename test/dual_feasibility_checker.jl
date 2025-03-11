# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestDualFeasibilityChecker

import ModelAnalyzer
using Test
using JuMP
import Dualization

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
    @test_throws ErrorException ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(),
    )
    # no dual solutions available
    @test_throws ErrorException ModelAnalyzer.dual_feasibility_report(model)
end

function test_only_bounds()
    # in this case the dual has no varaibles and has innocuous constraints
    # this needs to be reviewed in Dualization.jl
    model = Model()
    @variable(model, x >= 0)
    @objective(model, Min, x)
    # md = Dualization.dualize(model)
    # print(md)
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(LowerBoundRef(x) => 1.0),
    )
    @test isempty(report)
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
    report = ModelAnalyzer.dual_feasibility_report(model, Dict(c => 1.0))
    @test isempty(report)
    report = ModelAnalyzer.dual_feasibility_report(model, Dict(c => [1.0]))
    @test isempty(report)
    report =
        ModelAnalyzer.dual_feasibility_report(model, Dict(c => [3.3]))
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
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [1.0], LowerBoundRef(x) => [0.0]),
    )
    @test isempty(report)
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[LowerBoundRef(x)] == 2.3
    @test length(report) == 1
    report = ModelAnalyzer.dual_feasibility_report(
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
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [1.0], LowerBoundRef(x) => [0.0]),
    )
    @test isempty(report)
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[x] == 2.3
    @test length(report) == 1
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [-3.3], LowerBoundRef(x) => [0.0]),
    )
    @test report[x] == 4.3
    @test report[c] == 3.3
    @test length(report) == 2
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [-3.3], LowerBoundRef(x) => [-1.0]),
    )
    @test report[x] == 5.3
    @test report[c] == 3.3
    @test report[LowerBoundRef(x)] == 1.0
    @test length(report) == 3
    report = ModelAnalyzer.dual_feasibility_report(
        model,
        Dict(c => [-3.3]),
        skip_missing = true,
    )
    @test report[c] == 3.3
    @test length(report) == 1
end

end # module

TestDualFeasibilityChecker.runtests()
