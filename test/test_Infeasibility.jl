# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestInfeasibility

using JuMP
using Test

import HiGHS
import MathOptAnalyzer
import SCS

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
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] == MathOptAnalyzer.Infeasibility.InfeasibleBounds{Float64}(
        JuMP.index(y),
        2.0,
        1.0,
    )
    @test MathOptAnalyzer.variable(ret[], model) == y
    @test MathOptAnalyzer.values(ret[]) == [2.0, 1.0]
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.InfeasibleBounds{Float64},
    )
    str = String(take!(buf))
    @test startswith(str, "# `InfeasibleBounds`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.InfeasibleBounds{Float64},
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# InfeasibleBounds"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with lower bound ")
    @test contains(str, " and upper bound ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : ")
    @test contains(str, " !<= ")
    MathOptAnalyzer.summarize(buf, data, verbose = false)
    MathOptAnalyzer.summarize(buf, data, verbose = true)
    return
end

function test_integrality()
    model = Model()
    @variable(model, 0 <= x <= 1, Int)
    @variable(model, 2.2 <= y <= 2.9, Int)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] == MathOptAnalyzer.Infeasibility.InfeasibleIntegrality{Float64}(
        JuMP.index(y),
        2.2,
        2.9,
        MOI.Integer(),
    )
    @test MathOptAnalyzer.variable(ret[], model) == y
    @test MathOptAnalyzer.values(ret[]) == [2.2, 2.9]
    @test MathOptAnalyzer.set(ret[]) == MOI.Integer()
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.InfeasibleIntegrality{Float64},
    )
    str = String(take!(buf))
    @test startswith(str, "# `InfeasibleIntegrality`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.InfeasibleIntegrality{Float64},
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# InfeasibleIntegrality"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Variable: ")
    @test contains(str, " with lower bound ")
    @test contains(str, " and upper bound ")
    @test contains(str, " and integrality constraint: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : [")
    @test contains(str, "; ")
    @test contains(str, "], ")
    MathOptAnalyzer.summarize(buf, data, verbose = false)
    MathOptAnalyzer.summarize(buf, data, verbose = true)
    return
end

function test_binary()
    model = Model()
    @variable(model, 0.5 <= x <= 0.8, Bin)
    @variable(model, 0 <= y <= 1, Bin)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] == MathOptAnalyzer.Infeasibility.InfeasibleIntegrality{Float64}(
        JuMP.index(x),
        0.5,
        0.8,
        MOI.ZeroOne(),
    )
    @test MathOptAnalyzer.variable(ret[], model) == x
    @test MathOptAnalyzer.values(ret[]) == [0.5, 0.8]
    @test MathOptAnalyzer.set(ret[]) == MOI.ZeroOne()
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data, verbose = false)
    MathOptAnalyzer.summarize(buf, data, verbose = true)
    return
end

function test_range()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, c, x + y <= 1)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        JuMP.index(c),
        11.0,
        22.0,
        MOI.LessThan{Float64}(1.0),
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.values(ret[]) == [11.0, 22.0]
    @test MathOptAnalyzer.set(ret[]) == MOI.LessThan{Float64}(1.0)
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64},
    )
    str = String(take!(buf))
    @test startswith(str, "# `InfeasibleConstraintRange`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64},
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# InfeasibleConstraintRange"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Constraint: ")
    @test contains(str, " with computed lower bound ")
    @test contains(str, " and computed upper bound ")
    @test contains(str, " and set: ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test contains(str, " : [")
    @test contains(str, "; ")
    @test contains(str, "], !in ")
    MathOptAnalyzer.summarize(buf, data, verbose = false)
    MathOptAnalyzer.summarize(buf, data, verbose = true)
    return
end

function test_range_neg()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, -11 <= y <= -1)
    @constraint(model, c, x - y <= 1)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        JuMP.index(c),
        11.0,
        22.0,
        MOI.LessThan{Float64}(1.0),
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.values(ret[]) == [11.0, 22.0]
    @test MathOptAnalyzer.set(ret[]) == MOI.LessThan{Float64}(1.0)
    return
end

function test_range_equalto()
    model = Model()
    @variable(model, x == 1)
    @variable(model, y == 2)
    @constraint(model, c, x + y == 1)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        JuMP.index(c),
        3.0,
        3.0,
        MOI.EqualTo{Float64}(1.0),
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.values(ret[]) == [3.0, 3.0]
    @test MathOptAnalyzer.set(ret[]) == MOI.EqualTo{Float64}(1.0)
    return
end

function test_range_equalto_2()
    model = Model()
    @variable(model, x == 1)
    @variable(model, y == 2)
    @constraint(model, c, 3x + 2y == 1)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        JuMP.index(c),
        7.0,
        7.0,
        MOI.EqualTo{Float64}(1.0),
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.values(ret[]) == [7.0, 7.0]
    @test MathOptAnalyzer.set(ret[]) == MOI.EqualTo{Float64}(1.0)
    return
end

function test_range_greaterthan()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, c, x + y >= 100)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        JuMP.index(c),
        11.0,
        22.0,
        MOI.GreaterThan{Float64}(100.0),
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.values(ret[]) == [11.0, 22.0]
    @test MathOptAnalyzer.set(ret[]) == MOI.GreaterThan{Float64}(100.0)
    return
end

function test_range_equalto_3()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, c, x + y == 100)
    @objective(model, Max, x + y)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test ret[] ==
          MathOptAnalyzer.Infeasibility.InfeasibleConstraintRange{Float64}(
        JuMP.index(c),
        11.0,
        22.0,
        MOI.EqualTo{Float64}(100.0),
    )
    @test MathOptAnalyzer.constraint(ret[], model) == c
    @test MathOptAnalyzer.values(ret[]) == [11.0, 22.0]
    @test MathOptAnalyzer.set(ret[]) == MOI.EqualTo{Float64}(100.0)
    return
end

function test_interval()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x in MOI.Interval(0, 10))
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @objective(model, Max, x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
end

function test_iis_feasible()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @objective(model, Max, x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
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
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ==
          Set(JuMP.index.([c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) == Set([c2, c1])
    #
    buf = IOBuffer()
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.IrreducibleInfeasibleSubset,
    )
    str = String(take!(buf))
    @test startswith(str, "# `IrreducibleInfeasibleSubset`")
    MathOptAnalyzer.summarize(
        buf,
        MathOptAnalyzer.Infeasibility.IrreducibleInfeasibleSubset,
        verbose = false,
    )
    str = String(take!(buf))
    @test str == "# IrreducibleInfeasibleSubset"
    #
    MathOptAnalyzer.summarize(buf, ret[1], verbose = true)
    str = String(take!(buf))
    @test startswith(str, "Irreducible Infeasible Subset: ")
    @test contains(str, ", ")
    MathOptAnalyzer.summarize(buf, ret[1], verbose = false)
    str = String(take!(buf))
    @test startswith(str, "IIS: ")
    @test contains(str, ", ")

    buf = IOBuffer()
    Base.show(buf, data)
    str = String(take!(buf))
    @test startswith(str, "Infeasibility analysis found 1 issues")

    MathOptAnalyzer.summarize(buf, data, verbose = true)
    str = String(take!(buf))
    @test startswith(str, "## Infeasibility Analysis\n\n")
    MathOptAnalyzer.summarize(buf, data, verbose = false)
    MathOptAnalyzer.summarize(buf, data, verbose = true)
    return
end

function test_iis_free_var()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, -2x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ==
          Set(JuMP.index.([c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) == Set([c2, c1])
    return
end

function test_iis_multiple()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c3, x + y <= 1.5)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test JuMP.index(c2) in Set([ret[].constraint[1], ret[].constraint[2]])
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ⊆
          Set(JuMP.index.([c3, c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) ⊆ Set([c3, c2, c1])
    @test c2 in iis
    return
end

function test_iis_interval_right()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, 0 <= x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ==
          Set(JuMP.index.([c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) == Set([c2, c1])
    return
end

function test_iis_interval_left()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, 2 <= x + y <= 5)
    @objective(model, Max, x + y)
    optimize!(model)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ==
          Set(JuMP.index.([c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) == Set([c2, c1])
    iis = MathOptAnalyzer.constraints(ret[], JuMP.backend(model))
    @test length(iis) == 2
    @test Set(iis) == Set(JuMP.index.([c2, c1]))
    return
end

function test_iis_spare()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @variable(model, 0 <= z <= 20)
    @constraint(model, c0, 2z <= 1)
    @constraint(model, c00, 3z <= 1)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data =
        MathOptAnalyzer.analyze(MathOptAnalyzer.Infeasibility.Analyzer(), model)
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = HiGHS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ==
          Set(JuMP.index.([c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) == Set([c2, c1])
    io = IOBuffer()
    MathOptAnalyzer.summarize(io, ret[1], verbose = true, model = model)
    return
end

function test_iis_bridges()
    model = Model(SCS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @variable(model, 0 <= z <= 20)
    @constraint(model, c0, 2z <= 1)
    @constraint(model, c00, 3z <= 1)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    @test termination_status(model) == INFEASIBLE
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model,
        optimizer = SCS.Optimizer,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 1
    ret = MathOptAnalyzer.list_of_issues(data, list[1])
    @test length(ret) == 1
    @test length(ret[].constraint) == 2
    @test Set([ret[].constraint[1], ret[].constraint[2]]) ==
          Set(JuMP.index.([c2, c1]))
    iis = MathOptAnalyzer.constraints(ret[], model)
    @test length(iis) == 2
    @test Set(iis) == Set([c2, c1])
    return
end

end  # module TestInfeasibility

TestInfeasibility.runtests()
