# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

module TestCoefficients

import ModelAnalyzer
import MathOptInterface as MOI
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

    data = ModelAnalyzer.coefficient_analysis(model)

    ret = sprint(show, data)
    # print(ret)
    ret = replace(ret, "JuMP." => "")
    @test ret == """
    Numerical stability report:
      Number of variables: 3
      Number of constraints: 5
      Number of nonzeros in matrix: 7
      Constraint types:
        * AffExpr-MathOptInterface.GreaterThan{Float64}: 1
        * AffExpr-MathOptInterface.LessThan{Float64}: 4
        * VariableRef-MathOptInterface.EqualTo{Float64}: 1
        * VariableRef-MathOptInterface.GreaterThan{Float64}: 1
        * VariableRef-MathOptInterface.LessThan{Float64}: 1
      Thresholds:
        Dense rows (fill-in): 0.1
        Dense rows (entries): 1000
        Small coefficients: 1.0e-5
        Large coefficients: 100000.0
      Coefficient ranges:
        matrix range     [6e-15, 7e+06]
        objective range  [8e-11, 1e+08]
        bounds range     [3e-09, 2e+09]
        rhs range        [2e-12, 4e+08]
      Variables not in constraints: 1
      Bound rows: 1
      Dense constraints: 0
      Empty constraints: 1
      Coefficients:
        matrix small: 1
        matrix large: 1
        bounds small: 1
        bounds large: 1
        rhs small: 1
        rhs large: 2
        objective small: 1
        objective large: 1

    WARNING: numerical stability issues detected
      - matrix range contains small coefficients
      - matrix range contains large coefficients
      - objective range contains small coefficients
      - objective range contains large coefficients
      - bounds range contains small coefficients
      - bounds range contains large coefficients
      - rhs range contains small coefficients
      - rhs range contains large coefficients
    Very large or small absolute values of coefficients
    can cause numerical stability issues. Consider
    reformulating the model.
    """

    ret = sprint((io, d) -> show(io, d, verbose = true), data)
    # print(ret)
    ret = replace(ret, "JuMP." => "")
    @test ret == """
    Numerical stability report:
      Number of variables: 3
      Number of constraints: 5
      Number of nonzeros in matrix: 7
      Constraint types:
        * AffExpr-MathOptInterface.GreaterThan{Float64}: 1
        * AffExpr-MathOptInterface.LessThan{Float64}: 4
        * VariableRef-MathOptInterface.EqualTo{Float64}: 1
        * VariableRef-MathOptInterface.GreaterThan{Float64}: 1
        * VariableRef-MathOptInterface.LessThan{Float64}: 1
      Thresholds:
        Dense rows (fill-in): 0.1
        Dense rows (entries): 1000
        Small coefficients: 1.0e-5
        Large coefficients: 100000.0
      Coefficient ranges:
        matrix range     [6e-15, 7e+06]
        objective range  [8e-11, 1e+08]
        bounds range     [3e-09, 2e+09]
        rhs range        [2e-12, 4e+08]
      Variables not in constraints: 1
      Bound rows: 1
      Dense constraints: 0
      Empty constraints: 1
      Coefficients:
        matrix small: 1
        matrix large: 1
        bounds small: 1
        bounds large: 1
        rhs small: 1
        rhs large: 2
        objective small: 1
        objective large: 1

      Variables not in constraints:
        * z

      Bound rows:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}(3)

      Empty constraints:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}(4)

      Small matrix coefficients:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.GreaterThan{Float64}}(1)-y: 6.0e-15

      Large matrix coefficients:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.GreaterThan{Float64}}(1)-x: 7.0e6

      Small bounds coefficients:
        * y: 3.0e-9

      Large bounds coefficients:
        * x: 2.0e9

      Small rhs coefficients:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.GreaterThan{Float64}}(1): -2.0e-12

      Large rhs coefficients:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}(1): 4.0e8
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}(2): -4.9999998e7

      Small objective coefficients:
        * y: 8.0e-11

      Large objective coefficients:
        * x: 1.0e8

    WARNING: numerical stability issues detected
      - matrix range contains small coefficients
      - matrix range contains large coefficients
      - objective range contains small coefficients
      - objective range contains large coefficients
      - bounds range contains small coefficients
      - bounds range contains large coefficients
      - rhs range contains small coefficients
      - rhs range contains large coefficients
    Very large or small absolute values of coefficients
    can cause numerical stability issues. Consider
    reformulating the model.
    """
    return
end

test_linear()

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

    data = ModelAnalyzer.coefficient_analysis(model)

    ret = sprint(show, data)
    # print(ret)
    ret = replace(ret, "JuMP." => "")
    @test ret == """
    Numerical stability report:
      Number of variables: 2
      Number of constraints: 9
      Number of nonzeros in matrix: 0
      Constraint types:
        * QuadExpr-MathOptInterface.EqualTo{Float64}: 3
        * QuadExpr-MathOptInterface.GreaterThan{Float64}: 3
        * QuadExpr-MathOptInterface.LessThan{Float64}: 3
        * VariableRef-MathOptInterface.GreaterThan{Float64}: 1
        * VariableRef-MathOptInterface.LessThan{Float64}: 1
      Thresholds:
        Dense rows (fill-in): 0.1
        Dense rows (entries): 1000
        Small coefficients: 1.0e-5
        Large coefficients: 100000.0

      Objective is quadratic:
      Objective is nonconvex (numerically)

      Coefficient ranges:
        matrix range     [1e+00, 1e+00]
        objective range  [1e+00, 1e+00]
        bounds range     [1e+00, 3e+00]
        rhs range        [1e+00, 4e+00]
        objective q range[1e+00, 1e+00]
        matrix q range   [1e+00, 1e+00]
      Variables not in constraints: 0
      Bound rows: 0
      Dense constraints: 0
      Empty constraints: 0
      Nonconvex constraints: 7
      Coefficients:
        matrix small: 0
        matrix large: 0
        bounds small: 0
        bounds large: 0
        rhs small: 0
        rhs large: 0
        objective small: 0
        objective large: 0
    """

    ret = sprint((io, d) -> show(io, d, verbose = true), data)
    # print(ret)
    ret = replace(ret, "JuMP." => "")
    @test ret == """
    Numerical stability report:
      Number of variables: 2
      Number of constraints: 9
      Number of nonzeros in matrix: 0
      Constraint types:
        * QuadExpr-MathOptInterface.EqualTo{Float64}: 3
        * QuadExpr-MathOptInterface.GreaterThan{Float64}: 3
        * QuadExpr-MathOptInterface.LessThan{Float64}: 3
        * VariableRef-MathOptInterface.GreaterThan{Float64}: 1
        * VariableRef-MathOptInterface.LessThan{Float64}: 1
      Thresholds:
        Dense rows (fill-in): 0.1
        Dense rows (entries): 1000
        Small coefficients: 1.0e-5
        Large coefficients: 100000.0

      Objective is quadratic:
      Objective is nonconvex (numerically)

      Coefficient ranges:
        matrix range     [1e+00, 1e+00]
        objective range  [1e+00, 1e+00]
        bounds range     [1e+00, 3e+00]
        rhs range        [1e+00, 4e+00]
        objective q range[1e+00, 1e+00]
        matrix q range   [1e+00, 1e+00]
      Variables not in constraints: 0
      Bound rows: 0
      Dense constraints: 0
      Empty constraints: 0
      Nonconvex constraints: 7
      Coefficients:
        matrix small: 0
        matrix large: 0
        bounds small: 0
        bounds large: 0
        rhs small: 0
        rhs large: 0
        objective small: 0
        objective large: 0

     Nonconvex quadratic constraints:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.EqualTo{Float64}}(1)
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.EqualTo{Float64}}(2)
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.EqualTo{Float64}}(3)
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.GreaterThan{Float64}}(2)
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.GreaterThan{Float64}}(3)
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.LessThan{Float64}}(1)
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarQuadraticFunction{Float64}, MathOptInterface.LessThan{Float64}}(3)
    """
    return
end

test_nonconvex_qp()

function test_dense()
    model = Model()
    @variable(model, x[1:10_000] <= 1)
    @constraint(model, sum(x) <= 4)

    data = ModelAnalyzer.coefficient_analysis(model)

    ret = sprint((io, d) -> show(io, d, verbose = true), data)
    # print(ret)
    ret = replace(ret, "JuMP." => "")
    @test ret == """
    Numerical stability report:
      Number of variables: 10000
      Number of constraints: 1
      Number of nonzeros in matrix: 10000
      Constraint types:
        * AffExpr-MathOptInterface.LessThan{Float64}: 1
        * VariableRef-MathOptInterface.LessThan{Float64}: 10000
      Thresholds:
        Dense rows (fill-in): 0.1
        Dense rows (entries): 1000
        Small coefficients: 1.0e-5
        Large coefficients: 100000.0
      Coefficient ranges:
        matrix range     [1e+00, 1e+00]
        objective range  [1e+00, 1e+00]
        bounds range     [1e+00, 1e+00]
        rhs range        [1e+00, 4e+00]
      Variables not in constraints: 0
      Bound rows: 0
      Dense constraints: 1
      Empty constraints: 0
      Coefficients:
        matrix small: 0
        matrix large: 0
        bounds small: 0
        bounds large: 0
        rhs small: 0
        rhs large: 0
        objective small: 0
        objective large: 0

      Dense constraints:
        * MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}(1): 10000
    """
end

test_dense()

function test_qp_range()
    model = Model()
    @variable(model, x)
    @variable(model, y)
    @constraint(model, c, 1e-7 * x^2 + 7e8 * y * y <= 4)
    @objective(model, Min, 3e-7 * x * x + 2e12 * y * y)

    data = ModelAnalyzer.coefficient_analysis(model)

    ret = sprint((io, d) -> show(io, d, verbose = true), data)
    # print(ret)
    ret = replace(ret, "JuMP." => "")
    @test ret == """
    Numerical stability report:
      Number of variables: 2
      Number of constraints: 1
      Number of nonzeros in matrix: 0
      Constraint types:
        * QuadExpr-MathOptInterface.LessThan{Float64}: 1
      Thresholds:
        Dense rows (fill-in): 0.1
        Dense rows (entries): 1000
        Small coefficients: 1.0e-5
        Large coefficients: 100000.0

      Objective is quadratic:
      Objective is convex (numerically)

      Coefficient ranges:
        matrix range     [1e+00, 1e+00]
        objective range  [1e+00, 1e+00]
        bounds range     [1e+00, 1e+00]
        rhs range        [1e+00, 4e+00]
        objective q range[3e-07, 2e+12]
        matrix q range   [1e-07, 7e+08]
      Variables not in constraints: 0
      Bound rows: 0
      Dense constraints: 0
      Empty constraints: 0
      Nonconvex constraints: 0
      Coefficients:
        matrix small: 0
        matrix large: 0
        bounds small: 0
        bounds large: 0
        rhs small: 0
        rhs large: 0
        objective small: 0
        objective large: 0

      Small objective quadratic coefficients:
        * x-x: 3.0e-7

      Large objective quadratic coefficients:
        * y-y: 2.0e12

      Small matrix quadratic coefficients:
        * c-x-x: 1.0e-7

      Large matrix quadratic coefficients:
        * c-y-y: 7.0e8

    WARNING: numerical stability issues detected
      - objective q range contains small coefficients
      - objective q range contains large coefficients
      - matrix q range contains small coefficients
      - matrix q range contains large coefficients
    Very large or small absolute values of coefficients
    can cause numerical stability issues. Consider
    reformulating the model.
    """
end

test_qp_range()

end  # module

TestCoefficients.runtests()
