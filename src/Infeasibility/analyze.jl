# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _add_result(
    out::Data,
    model,
    iis,
    meta::MathOptIIS.Metadata{T,Nothing},
) where {T}
    @assert length(iis.constraints) == 2
    err = InfeasibleBounds{T}(
        MOI.get(model, MOI.ConstraintFunction(), iis.constraints[1]),
        meta.lower_bound,
        meta.upper_bound,
    )
    push!(out.infeasible_bounds, err)
    return
end

function _add_result(
    out::Data,
    model,
    iis,
    meta::MathOptIIS.Metadata{T,S},
) where {T,S<:Union{MOI.Integer,MOI.ZeroOne}}
    @assert length(iis.constraints) >= 2
    err = InfeasibleIntegrality{T}(
        MOI.get(model, MOI.ConstraintFunction(), iis.constraints[1]),
        meta.lower_bound,
        meta.upper_bound,
        meta.set,
    )
    push!(out.infeasible_integrality, err)
    return
end

function _add_result(
    out::Data,
    model,
    iis,
    meta::MathOptIIS.Metadata{T,S},
) where {T,S<:MOI.AbstractSet}
    @assert length(iis.constraints) >= 1
    for con in iis.constraints
        if con isa MOI.ConstraintIndex{MOI.VariableIndex}
            continue
        end
        err = InfeasibleConstraintRange{T}(
            con,
            meta.lower_bound,
            meta.upper_bound,
            meta.set,
        )
        push!(out.constraint_range, err)
        break
    end
    return
end

function _add_result(out::Data, model, iis, meta)
    push!(out.iis, IrreducibleInfeasibleSubset(iis.constraints))
    return
end

function MathOptAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike;
    optimizer = nothing,
)
    solver = MathOptIIS.Optimizer()
    MOI.set(solver, MathOptIIS.InfeasibleModel(), model)
    if optimizer !== nothing
        MOI.set(solver, MathOptIIS.InnerOptimizer(), optimizer)
    end
    MOI.compute_conflict!(solver)
    out = Data()
    for iis in solver.results
        _add_result(out, model, iis, iis.metadata)
    end
    return out
end
