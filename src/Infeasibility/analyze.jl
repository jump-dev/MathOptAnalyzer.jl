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

# ==============================================================================
# Native IIS path: use solver's built-in compute_conflict! if available
# ==============================================================================

"""
    _reverse_index_map(index_map::MOI.IndexMap)

Return a dictionary mapping constraint indices in the destination model back to
constraint indices in the source model.
"""
function _reverse_index_map(index_map::MOI.IndexMap)
    ret = Dict{MOI.ConstraintIndex,MOI.ConstraintIndex}()
    for (k, v) in index_map.con_map
        ret[v] = k
    end
    return ret
end

"""
    _is_variable_constraint(ci::MOI.ConstraintIndex)

Return `true` if the constraint index is a variable-level constraint
(i.e., `F == MOI.VariableIndex`).
"""
_is_variable_constraint(::MOI.ConstraintIndex{MOI.VariableIndex}) = true
_is_variable_constraint(::MOI.ConstraintIndex) = false

"""
    _is_integrality_constraint(ci::MOI.ConstraintIndex)

Return `true` if the constraint index is a variable integrality or binary
constraint.
"""
function _is_integrality_constraint(
    ::MOI.ConstraintIndex{MOI.VariableIndex,S},
) where {S}
    return S <: Union{MOI.Integer,MOI.ZeroOne}
end
_is_integrality_constraint(::MOI.ConstraintIndex) = false

"""
    _is_bound_constraint(ci::MOI.ConstraintIndex)

Return `true` if the constraint index is a variable bound constraint
(LessThan, GreaterThan, EqualTo, or Interval on a VariableIndex).
"""
function _is_bound_constraint(
    ::MOI.ConstraintIndex{MOI.VariableIndex,S},
) where {S}
    return S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo,MOI.Interval}
end
_is_bound_constraint(::MOI.ConstraintIndex) = false

"""
    _classify_variable_conflict!(out, model, x, bound_cis, has_integrality, integrality_set)

Given a variable `x` with conflicting bound constraints `bound_cis`,
classify the conflict as `InfeasibleBounds` or `InfeasibleIntegrality`.
"""
function _classify_variable_conflict!(
    out::Data,
    model::MOI.ModelLike,
    x::MOI.VariableIndex,
    bound_cis::Vector{MOI.ConstraintIndex},
    has_integrality::Bool,
    integrality_set::Union{Nothing,MOI.Integer,MOI.ZeroOne},
)
    # Compute bounds from the conflicting bound constraints
    T = Float64
    lb = typemin(T)
    ub = typemax(T)
    for ci in bound_cis
        s = MOI.get(model, MOI.ConstraintSet(), ci)
        if s isa MOI.GreaterThan
            lb = max(lb, s.lower)
        elseif s isa MOI.LessThan
            ub = min(ub, s.upper)
        elseif s isa MOI.EqualTo
            lb = max(lb, s.value)
            ub = min(ub, s.value)
        elseif s isa MOI.Interval
            lb = max(lb, s.lower)
            ub = min(ub, s.upper)
        end
    end
    if has_integrality && integrality_set !== nothing
        push!(
            out.infeasible_integrality,
            InfeasibleIntegrality{T}(x, lb, ub, integrality_set),
        )
    elseif ub < lb
        push!(out.infeasible_bounds, InfeasibleBounds{T}(x, lb, ub))
    end
    return
end

"""
    _categorize_native_iis!(out, model, conflicting)

Categorize a flat list of conflicting constraint indices (from a native solver
IIS) into the typed issue buckets in `out::Data`.
"""
function _categorize_native_iis!(
    out::Data,
    model::MOI.ModelLike,
    conflicting::Vector{MOI.ConstraintIndex},
)
    # Partition constraints by variable (for variable-level) vs scalar
    var_bounds = Dict{MOI.VariableIndex,Vector{MOI.ConstraintIndex}}()
    var_integrality = Dict{MOI.VariableIndex,Union{MOI.Integer,MOI.ZeroOne}}()
    scalar_constraints = MOI.ConstraintIndex[]

    for ci in conflicting
        if _is_bound_constraint(ci)
            x = MOI.VariableIndex(ci.value)
            push!(get!(Vector{MOI.ConstraintIndex}, var_bounds, x), ci)
        elseif _is_integrality_constraint(ci)
            x = MOI.VariableIndex(ci.value)
            s = MOI.get(model, MOI.ConstraintSet(), ci)
            var_integrality[x] = s
        else
            push!(scalar_constraints, ci)
        end
    end

    # Classify variable-level conflicts
    for (x, cis) in var_bounds
        has_int = haskey(var_integrality, x)
        int_set = get(var_integrality, x, nothing)
        _classify_variable_conflict!(out, model, x, cis, has_int, int_set)
    end

    # If there are scalar constraints in conflict, they form an IIS together
    # with any associated variable bounds
    if !isempty(scalar_constraints)
        push!(out.iis, IrreducibleInfeasibleSubset(conflicting))
    end
    return
end

"""
    _analyze_native_iis(model, optimizer)

Use the solver's native `MOI.compute_conflict!` to find an IIS and categorize
the results into an `Infeasibility.Data` struct.
"""
function _analyze_native_iis(model::MOI.ModelLike, optimizer)
    # Instantiate solver with bridges so that constraint types the solver
    # doesn't natively support (e.g. Interval) are automatically transformed.
    solver = MOI.instantiate(optimizer; with_bridge_type = Float64)
    if MOI.supports(solver, MOI.Silent())
        MOI.set(solver, MOI.Silent(), true)
    end
    index_map = MOI.copy_to(solver, model)
    reverse_map = _reverse_index_map(index_map)

    MOI.compute_conflict!(solver)

    status = MOI.get(solver, MOI.ConflictStatus())
    out = Data()
    if status != MOI.CONFLICT_FOUND
        return out
    end

    # Collect all conflicting constraints, mapped back to original model
    conflicting = MOI.ConstraintIndex[]
    for (F, S) in MOI.get(solver, MOI.ListOfConstraintTypesPresent())
        for ci in MOI.get(solver, MOI.ListOfConstraintIndices{F,S}())
            cs = try
                MOI.get(solver, MOI.ConstraintConflictStatus(), ci)
            catch
                # Some constraint types may not support conflict status query
                continue
            end
            if cs in (MOI.IN_CONFLICT, MOI.MAYBE_IN_CONFLICT)
                # Map back to original model index
                original_ci = get(reverse_map, ci, nothing)
                if original_ci !== nothing
                    push!(conflicting, original_ci)
                end
            end
        end
    end

    # Categorize into typed issue buckets
    _categorize_native_iis!(out, model, conflicting)
    return out
end

# ==============================================================================
# Main entry point
# ==============================================================================

function MathOptAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike;
    optimizer = nothing,
    native_iis::Bool = false,
)
    # Use native solver IIS if requested
    if native_iis && optimizer !== nothing
        try
            return _analyze_native_iis(model, optimizer)
        catch err
            # Only swallow errors indicating the solver doesn't support
            # compute_conflict! — rethrow anything else
            if !(err isa Union{MethodError,MOI.UnsupportedError,ErrorException})
                rethrow(err)
            end
            @warn(
                "Native IIS computation failed ($(typeof(err))); " *
                "falling back to MathOptIIS elastic filter.",
            )
            @error("Error details: $err")
        end
    end
    # Fallback: MathOptIIS elastic-filter path
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
