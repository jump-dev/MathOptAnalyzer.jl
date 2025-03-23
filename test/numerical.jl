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

function test_linear()
    model = Model()
    @variable(model, x <= 2e9)
    @variable(model, y >= 3e-9)
    @variable(model, z == 4e-9)
    @constraint(model, x + y <= 4e8)
    @constraint(model, x + y + 5e7 <= 2)
    @constraint(model, 7e6 * x + 6e-15 * y + 2e-12 >= 0)
    @constraint(model, x <= 100)
    @constraint(model, 0 * x <= 100)
    @objective(model, Max, 1e8 * x + 8e-11 * y)

    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)

    ret = sprint(show, data)
    print(ret)

    ModelAnalyzer.summarize(data)

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

    ret = sprint(show, data)
    print(ret)

    ModelAnalyzer.summarize(data)

    return
end

function test_dense()
    model = Model()
    @variable(model, x[1:10_000] <= 1)
    @constraint(model, sum(x) <= 4)

    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)

    ret = sprint(show, data)
    print(ret)

    return ModelAnalyzer.summarize(data)
end

function test_qp_range()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c, 1e-7 * x^2 + 7e8 * y * y <= 4)
    @objective(model, Min, 3e-7 * x * x + 2e12 * y * y)

    data = ModelAnalyzer.analyze(ModelAnalyzer.Numerical.Analyzer(), model)

    ret = sprint(show, data)
    print(ret)

    return ModelAnalyzer.summarize(data)
end

end  # module

TestNumerical.runtests()
