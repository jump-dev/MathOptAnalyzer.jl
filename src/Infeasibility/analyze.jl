# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

import MathOptIIS as MOIIS

function MathOptAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike;
    optimizer = nothing,
)
    out = Data()
    T = Float64

    solver = MOIIS.Optimizer()
    MOI.set(solver, MOIIS.InfeasibleModel(), model)

    if optimizer !== nothing
        MOI.set(solver, MOIIS.InnerOptimizer(), optimizer)
    end

    MOI.compute_conflict!(solver)

    data = solver.results

    for iis in data
        meta = iis.metadata
        if typeof(meta) <: MOIIS.BoundsData
            constraints = iis.constraints
            @assert length(constraints) == 2
            func = MOI.get(model, MOI.ConstraintFunction(), constraints[1])
            push!(
                out.infeasible_bounds,
                InfeasibleBounds{T}(func, meta.lower_bound, meta.upper_bound),
            )
        elseif typeof(meta) <: MOIIS.IntegralityData
            constraints = iis.constraints
            @assert length(constraints) >= 2
            func = MOI.get(model, MOI.ConstraintFunction(), constraints[1])
            push!(
                out.infeasible_integrality,
                InfeasibleIntegrality{T}(func, meta.lower_bound, meta.upper_bound, meta.set),
            )
        elseif typeof(meta) <: MOIIS.RangeData
            constraints = iis.constraints
            @assert length(constraints) >= 1
            # main_con = nothing
            for con in constraints
                if !(typeof(con) <: MOI.ConstraintIndex{MOI.VariableIndex})
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange{T}(con, meta.lower_bound, meta.upper_bound, meta.set),
                    )
                    break
                end
            end
        else
            push!(
                out.iis,
                IrreducibleInfeasibleSubset(iis.constraints),
            )
        end
    end
    return out
end
