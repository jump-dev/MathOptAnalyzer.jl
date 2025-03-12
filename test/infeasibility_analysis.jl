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

function test_bounds()
    model = Model()
    @variable(model, 0 <= x <= 1)
    @variable(model, 2 <= y <= 1)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    # optimize!(model)
    data = ModelAnalyzer.infeasibility_analysis(model)
    # @show data
    @test length(data.infeasible_bounds) == 1
    @test length(data.infeasible_integrality) == 0
    @test length(data.constraint_range) == 0
    @test length(data.iis) == 0
    return
end

function test_integrality()
    model = Model()
    @variable(model, 0 <= x <= 1, Int)
    @variable(model, 2.2 <= y <= 2.9, Int)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    # optimize!(model)
    data = ModelAnalyzer.infeasibility_analysis(model)
    # @show data
    @test length(data.infeasible_bounds) == 0
    @test length(data.infeasible_integrality) == 1
    @test length(data.constraint_range) == 0
    @test length(data.iis) == 0
    return
end

function test_binary()
    model = Model()
    @variable(model, 0.5 <= x <= 0.8, Bin)
    @variable(model, 0 <= y <= 1, Bin)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    # optimize!(model)
    data = ModelAnalyzer.infeasibility_analysis(model)
    # @show data
    @test length(data.infeasible_bounds) == 0
    @test length(data.infeasible_integrality) == 1
    @test length(data.constraint_range) == 0
    @test length(data.iis) == 0
    return
end

function test_range()
    model = Model()
    @variable(model, 10 <= x <= 11)
    @variable(model, 1 <= y <= 11)
    @constraint(model, x + y <= 1)
    @objective(model, Max, x + y)
    # optimize!(model)
    data = ModelAnalyzer.infeasibility_analysis(model)
    # @show data
    @test length(data.infeasible_bounds) == 0
    @test length(data.infeasible_integrality) == 0
    @test length(data.constraint_range) == 1
    @test length(data.iis) == 0
    return
end

function test_iis()
    model = Model(HiGHS.Optimizer)
    set_silent(model)
    @variable(model, 0 <= x <= 10)
    @variable(model, 0 <= y <= 20)
    @constraint(model, x + y <= 1)
    @constraint(model, x + y >= 2)
    @objective(model, Max, x + y)
    optimize!(model)
    data =
        ModelAnalyzer.infeasibility_analysis(model, optimizer = HiGHS.Optimizer)
    # @show data
    @test length(data.infeasible_bounds) == 0
    @test length(data.infeasible_integrality) == 0
    @test length(data.constraint_range) == 0
    @test length(data.iis) == 1
    return
end

end # module

TestDualFeasibilityChecker.runtests()
