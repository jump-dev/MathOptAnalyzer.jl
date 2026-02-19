# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _add_result(out::Data, model, iis, meta::MOIIS.BoundsData)
    @assert length(iis.constraints) == 2
    err = InfeasibleBounds{Float64}(
        MOI.get(model, MOI.ConstraintFunction(), iis.constraints[1]),
        meta.lower_bound,
        meta.upper_bound,
    )
    push!(out.infeasible_bounds, err)
    return
end

function _add_result(out::Data, model, iis, meta::MOIIS.IntegralityData)
    @assert length(iis.constraints) >= 2
    err = InfeasibleIntegrality{Float64}(
        MOI.get(model, MOI.ConstraintFunction(), iis.constraints[1]),
        meta.lower_bound,
        meta.upper_bound,
        meta.set,
    )
    push!(out.infeasible_integrality, err)
    return
end

function _add_result(out::Data, model, iis, meta::MOIIS.RangeData)
    @assert length(iis.constraints) >= 1
    for con in iis.constraints
        if con isa MOI.ConstraintIndex{MOI.VariableIndex}
            continue
        end
        err = InfeasibleConstraintRange{Float64}(
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

function _instantiate_with_modify(optimizer, ::Type{T}) where {T}
    model = MOI.instantiate(optimizer)
    if !MOI.supports_incremental_interface(model)
        # Don't use `default_cache` for the cache because, for example, SCS's
        # default cache doesn't support modifying coefficients of the constraint
        # matrix. JuMP uses the default cache with SCS because it has an outer
        # layer of caching; we don't have that here, so we can't use the
        # default.
        #
        # We could revert to using the default cache if we fix this in MOI.
        cache = MOI.Utilities.UniversalFallback(MOI.Utilities.Model{T}())
        model = MOI.Utilities.CachingOptimizer(cache, model)
    end
    return MOI.Bridges.full_bridge_optimizer(model, T)
end

function MathOptAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike;
    optimizer = nothing,
)
    solver = MOIIS.Optimizer()
    MOI.set(solver, MOIIS.InfeasibleModel(), model)
    if optimizer !== nothing
        MOI.set(
            solver,
            MOIIS.InnerOptimizer(),
            () -> _instantiate_with_modify(optimizer, Float64),
        )
    end
    MOI.compute_conflict!(solver)
    out = Data()
    for iis in solver.results
        _add_result(out, model, iis, iis.metadata)
    end
    return out
end
