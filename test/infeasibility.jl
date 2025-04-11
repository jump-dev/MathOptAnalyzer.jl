# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestInfeasibilityChecker

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

function test_bounds()
    model = Model()
    @variable(model, 0 <= x <= 1)
    @variable(model, 2 <= y <= 1)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          ModelAnalyzer.Infeasibility.InfeasibleBounds{Float64}(y, 2.0, 1.0)
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Infeasibility.InfeasibleBounds{Float64},
    )
    str = String(take!(buf))
    @test startswith(str, "# `InfeasibleBounds`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Infeasibility.InfeasibleBounds{Float64},
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# InfeasibleBounds"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with lower bound ")
    @test contains(str, " and upper bound ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    @test contains(str, " !<= ")
    return
end

function test_integrality()
    model = Model()
    @variable(model, 0 <= x <= 1, Int)
    @variable(model, 2.2 <= y <= 2.9, Int)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] == ModelAnalyzer.Infeasibility.InfeasibleIntegrality{Float64}(
        y,
        2.2,
        2.9,
        MOI.Integer(),
    )
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Infeasibility.InfeasibleIntegrality{Float64},
    )
    str = String(take!(buf))
    @test startswith(str, "# `InfeasibleIntegrality`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Infeasibility.InfeasibleIntegrality{Float64},
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# InfeasibleIntegrality"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with lower bound ")
    @test contains(str, " and upper bound ")
    @test contains(str, " and integrality constraint: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : [")
    @test contains(str, "; ")
    @test contains(str, "], ")
    return
end

function test_binary()
    model = Model()
    @variable(model, 0.5 <= x <= 0.8, Bin)
    @variable(model, 0 <= y <= 1, Bin)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] == ModelAnalyzer.Infeasibility.InfeasibleIntegrality{Float64}(
        x,
        0.5,
        0.8,
        MOI.ZeroOne(),
    )
    return
end

function test_range()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, c, x + y <= 1)
    @objective(model, Max, x + y)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          ModelAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        c,
        11.0,
        22.0,
        MOI.LessThan{Float64}(1.0),
    )
    #
    buf = IOBuffer()
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64},
    )
    str = String(take!(buf))
    @test startswith(str, "# `InfeasibleConstraintRange`")
    ModelAnalyzer.summarize(
        buf,
        ModelAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64},
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# InfeasibleConstraintRange"
    #
    ModelAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with computed lower bound ")
    @test contains(str, " and computed upper bound ")
    @test contains(str, " and set: ")
    ModelAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : [")
    @test contains(str, "; ")
    @test contains(str, "], !in ")
    return
end

function test_range_greaterthan()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, c, x + y >= 100)
    @objective(model, Max, x + y)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          ModelAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        c,
        11.0,
        22.0,
        MOI.GreaterThan{Float64}(100.0),
    )
    return
end

function test_range_equalto()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, c, x + y == 100)
    @objective(model, Max, x + y)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          ModelAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        c,
        11.0,
        22.0,
        MOI.EqualTo{Float64}(100.0),
    )
    return
end

function test_iis_feasible()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @objective(model, Max, x + y)
    optimize!(model)
    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
end

function test_iis()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data = ModelAnalyzer.analyze(ModelAnalyzer.Infeasibility.Analyzer(), model)
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = ModelAnalyzer.analyze(
        ModelAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = ModelAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = ModelAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test ret[].constraint[1] == c2
    @test ret[].constraint[2] == c1
    return
end

end # module

TestInfeasibilityChecker.runtests()
