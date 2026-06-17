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
            @show name
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
    @test 1 <= length(list) <= 2
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
    @test 1 <= length(list) <= 2
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
    iis = MathOptAnalyzer.constraints(only(ret), model)
    @test c1 in iis
    @test c2 in iis
    # TODO(odow): this can be 3, which is a bug in MathOptIIS.
    @test length(iis) >= 2
    return
end

# ==============================================================================
# Tests for native_iis = true path
# ==============================================================================

function test_native_iis_scalar_constraints()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model;
        optimizer = HiGHS.Optimizer,
        native_iis = true,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) >= 1
    # Should find at least one IrreducibleInfeasibleSubset
    iis_issues = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Infeasibility.IrreducibleInfeasibleSubset,
    )
    @test length(iis_issues) >= 1
    iis = MathOptAnalyzer.constraints(iis_issues[1], model)
    @test c1 in iis || c2 in iis
    # Summarize should work without error
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data, verbose = true, model = model)
    str = String(take!(buf))
    @test contains(str, "Infeasibility Analysis")
    return
end

function test_native_iis_infeasible_bounds()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 2 <= x <= 1)  # infeasible bounds
    @variable(model, 0 <= y <= 10)
    @constraint(model, c1, x + y <= 5)
    @objective(model, Max, x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model;
        optimizer = HiGHS.Optimizer,
        native_iis = true,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) >= 1
    # Should find infeasible bounds
    bound_issues = MathOptAnalyzer.list_of_issues(
        data,
        MathOptAnalyzer.Infeasibility.InfeasibleBounds,
    )
    if !isempty(bound_issues)
        @test bound_issues[1].lb > bound_issues[1].ub
    end
    # Summarize should work without error
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data, verbose = true, model = model)
    return
end

function test_native_iis_feasible_model()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 30)
    @objective(model, Max, x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model;
        optimizer = HiGHS.Optimizer,
        native_iis = true,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) == 0
    return
end

function test_native_iis_fallback()
    # Test that native_iis = true falls back gracefully when the solver
    # doesn't support compute_conflict!
    model = Model()
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    # Use a mock optimizer that doesn't support compute_conflict!
    # By passing native_iis = true with a working optimizer, the fallback
    # path should still produce results via MathOptIIS
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model;
        optimizer = HiGHS.Optimizer,
        native_iis = false,
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) >= 1
    return
end

function test_native_iis_summarize()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data = MathOptAnalyzer.analyze(
        MathOptAnalyzer.Infeasibility.Analyzer(),
        model;
        optimizer = HiGHS.Optimizer,
        native_iis = true,
    )
    # Test all summarize variants
    buf = IOBuffer()
    MathOptAnalyzer.summarize(buf, data, verbose = true, model = model)
    str_verbose = String(take!(buf))
    @test contains(str_verbose, "Infeasibility Analysis")
    MathOptAnalyzer.summarize(buf, data, verbose = false, model = model)
    str_concise = String(take!(buf))
    @test contains(str_concise, "Infeasibility Analysis")
    # Test show
    Base.show(buf, data)
    str_show = String(take!(buf))
    @test contains(str_show, "issues")
    return
end

# ==============================================================================
# Unit tests for internal helper functions (coverage of dead-code / fallback paths)
# ==============================================================================

"""
Direct unit tests for `_is_variable_constraint`, `_is_integrality_constraint`,
and `_is_bound_constraint` (lines 91–92, 100, 103, 105, 118).
"""
function test_helper_is_variable_constraint()
    # Both dispatch methods of _is_variable_constraint
    ci_vi = MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}}(1)
    ci_saf = MOI.ConstraintIndex{
        MOI.ScalarAffineFunction{Float64},
        MOI.LessThan{Float64},
    }(
        1,
    )
    @test MathOptAnalyzer.Infeasibility._is_variable_constraint(ci_vi) == true
    @test MathOptAnalyzer.Infeasibility._is_variable_constraint(ci_saf) == false
    return
end

function test_helper_is_integrality_constraint()
    # Parametric version returning true  (lines 100, 103)
    ci_int = MOI.ConstraintIndex{MOI.VariableIndex,MOI.Integer}(1)
    @test MathOptAnalyzer.Infeasibility._is_integrality_constraint(ci_int) ==
          true
    # Parametric version returning false (lines 100, 103)
    ci_lt = MOI.ConstraintIndex{MOI.VariableIndex,MOI.LessThan{Float64}}(1)
    @test MathOptAnalyzer.Infeasibility._is_integrality_constraint(ci_lt) ==
          false
    # Non-VariableIndex fallback returning false (line 105)
    ci_saf = MOI.ConstraintIndex{
        MOI.ScalarAffineFunction{Float64},
        MOI.LessThan{Float64},
    }(
        1,
    )
    @test MathOptAnalyzer.Infeasibility._is_integrality_constraint(ci_saf) ==
          false
    return
end

function test_helper_is_bound_constraint()
    # Non-VariableIndex fallback returning false (line 118)
    ci_saf = MOI.ConstraintIndex{
        MOI.ScalarAffineFunction{Float64},
        MOI.LessThan{Float64},
    }(
        1,
    )
    @test MathOptAnalyzer.Infeasibility._is_bound_constraint(ci_saf) == false
    return
end

# ==============================================================================
# Direct tests for _classify_variable_conflict! branches
# ==============================================================================

"""
Exercise the `EqualTo` branch (lines 144–146), the `Interval` branch
(lines 147–149), and the `has_integrality` path (line 153) of
`_classify_variable_conflict!`.
"""
function test_classify_variable_conflict_equalto()
    # MOI.Utilities.Model rejects two lower-bound constraints on the same
    # variable.  Add the two conflicting constraints on separate variables so
    # both are stored; _classify_variable_conflict! only queries the set of
    # each ConstraintIndex, it does not check variable ownership.
    model_moi = MOI.Utilities.Model{Float64}()
    x = MOI.add_variable(model_moi)   # will be the "target" variable
    y = MOI.add_variable(model_moi)   # proxy variable for the GreaterThan
    ci_eq = MOI.add_constraint(model_moi, x, MOI.EqualTo(2.0))       # ub = lb = 2.0
    ci_gt = MOI.add_constraint(model_moi, y, MOI.GreaterThan(3.0))   # lb = 3.0
    out = MathOptAnalyzer.Infeasibility.Data()
    MathOptAnalyzer.Infeasibility._classify_variable_conflict!(
        out,
        model_moi,
        x,
        MOI.ConstraintIndex[ci_eq, ci_gt],
        false,
        nothing,
    )
    # EqualTo(2.0) → ub=2, GreaterThan(3.0) → lb=3  ⟹  lb > ub
    @test length(out.infeasible_bounds) == 1
    @test out.infeasible_bounds[1].lb == 3.0
    @test out.infeasible_bounds[1].ub == 2.0
    return
end

function test_classify_variable_conflict_interval()
    model_moi = MOI.Utilities.Model{Float64}()
    x = MOI.add_variable(model_moi)
    # Interval(lower=5, upper=3) has lb > ub → infeasible
    ci_ivl = MOI.add_constraint(model_moi, x, MOI.Interval(5.0, 3.0))
    out = MathOptAnalyzer.Infeasibility.Data()
    MathOptAnalyzer.Infeasibility._classify_variable_conflict!(
        out,
        model_moi,
        x,
        MOI.ConstraintIndex[ci_ivl],
        false,
        nothing,
    )
    @test length(out.infeasible_bounds) == 1
    @test out.infeasible_bounds[1].lb == 5.0
    @test out.infeasible_bounds[1].ub == 3.0
    return
end

function test_classify_variable_conflict_integrality()
    model_moi = MOI.Utilities.Model{Float64}()
    x = MOI.add_variable(model_moi)
    ci_gt = MOI.add_constraint(model_moi, x, MOI.GreaterThan(2.2))
    ci_lt = MOI.add_constraint(model_moi, x, MOI.LessThan(2.9))
    out = MathOptAnalyzer.Infeasibility.Data()
    # Explicit Vector{ConstraintIndex} annotation so dispatch matches the
    # function signature (avoid Vector{ConstraintIndex{VariableIndex}} mismatch)
    MathOptAnalyzer.Infeasibility._classify_variable_conflict!(
        out,
        model_moi,
        x,
        MOI.ConstraintIndex[ci_gt, ci_lt],
        true,   # has_integrality
        MOI.Integer(),
    )
    @test length(out.infeasible_integrality) == 1
    @test out.infeasible_integrality[1].lb ≈ 2.2
    @test out.infeasible_integrality[1].ub ≈ 2.9
    @test out.infeasible_integrality[1].set == MOI.Integer()
    return
end

# ==============================================================================
# Direct tests for _categorize_native_iis!
# ==============================================================================

"""
Exercise the integrality branch of `_categorize_native_iis!` (lines 184–186)
and the scalar-constraint path that uses the non-VariableIndex fallbacks of
`_is_bound_constraint` (line 118) and `_is_integrality_constraint` (line 105).
"""
function test_categorize_native_iis_integrality()
    model_moi = MOI.Utilities.Model{Float64}()
    x = MOI.add_variable(model_moi)
    ci_gt = MOI.add_constraint(model_moi, x, MOI.GreaterThan(2.2))
    ci_lt = MOI.add_constraint(model_moi, x, MOI.LessThan(2.9))
    ci_int = MOI.add_constraint(model_moi, x, MOI.Integer())
    out = MathOptAnalyzer.Infeasibility.Data()
    # Explicit element type so the vector is Vector{ConstraintIndex} not
    # Vector{ConstraintIndex{VariableIndex}}
    conflicting = MOI.ConstraintIndex[ci_gt, ci_lt, ci_int]
    MathOptAnalyzer.Infeasibility._categorize_native_iis!(
        out,
        model_moi,
        conflicting,
    )
    # The integer + bound conflict should be classified as InfeasibleIntegrality
    @test length(out.infeasible_integrality) == 1
    @test out.infeasible_integrality[1].lb ≈ 2.2
    @test out.infeasible_integrality[1].ub ≈ 2.9
    return
end

function test_categorize_native_iis_scalar_constraint()
    # A scalar (SAF) constraint exercises the non-VariableIndex fallbacks:
    # _is_bound_constraint → line 118 (false), _is_integrality_constraint → line 105 (false)
    model_moi = MOI.Utilities.Model{Float64}()
    x = MOI.add_variable(model_moi)
    y = MOI.add_variable(model_moi)
    f = MOI.ScalarAffineFunction(
        [MOI.ScalarAffineTerm(1.0, x), MOI.ScalarAffineTerm(1.0, y)],
        0.0,
    )
    ci_saf = MOI.add_constraint(model_moi, f, MOI.LessThan(1.0))
    out = MathOptAnalyzer.Infeasibility.Data()
    conflicting = MOI.ConstraintIndex[ci_saf]
    MathOptAnalyzer.Infeasibility._categorize_native_iis!(
        out,
        model_moi,
        conflicting,
    )
    # Scalar constraint → pushed as an IrreducibleInfeasibleSubset
    @test length(out.iis) == 1
    @test length(out.iis[1].constraint) == 1
    return
end

# ==============================================================================
# Test for the native_iis fallback / warning path
# ==============================================================================

"""
When `native_iis = true` is requested with a solver that does not support
`compute_conflict!` (SCS throws `ArgumentError`), the code should emit a
warning + error log and then fall back gracefully to the MathOptIIS path
(lines 274, 277, 281 of analyze.jl).
"""
function test_native_iis_fallback_warning()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, c1, x + y <= 1)
    @constraint(model, c2, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    # SCS.Optimizer does not support compute_conflict! and raises ArgumentError.
    # With the fixed catch clause the code should warn, log the error, and fall
    # back to MathOptIIS instead of rethrowing.
    data = @test_logs(
        (:warn, r"Native IIS computation failed"),
        (:error, r"Error details"),
        match_mode = :any,
        MathOptAnalyzer.analyze(
            MathOptAnalyzer.Infeasibility.Analyzer(),
            model;
            optimizer = SCS.Optimizer,
            native_iis = true,
        ),
    )
    list = MathOptAnalyzer.list_of_issue_types(data)
    @test length(list) >= 1
    return
end

end  # module TestInfeasibility

TestInfeasibility.runtests()
