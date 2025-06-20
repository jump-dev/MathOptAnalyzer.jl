# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function ModelAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike;
    primal_point = nothing,
    dual_point = nothing,
    primal_objective::Union{Nothing,Float64} = nothing,
    dual_objective::Union{Nothing,Float64} = nothing,
    atol::Float64 = 1e-6,
    skip_missing::Bool = false,
    dual_check = true,
)
    can_dualize = false
    if dual_check
        can_dualize = _can_dualize(model)
        if !can_dualize
            println(
                "The model cannot be dualized. Automatically setting `dual_check = false`.",
            )
            dual_check = false
        end
    end

    data = Data(
        primal_point = primal_point,
        dual_point = dual_point,
        primal_objective = primal_objective,
        dual_objective = dual_objective,
        atol = atol,
        skip_missing = skip_missing,
        dual_check = dual_check,
    )

    if data.primal_point === nothing
        primal_status = MOI.get(model, MOI.PrimalStatus())
        if !(primal_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT))
            error(
                "No primal solution is available. You must provide a point at " *
                "which to check feasibility.",
            )
        end
        data.primal_point = _last_primal_solution(model)
    end

    if data.dual_point === nothing && dual_check
        dual_status = MOI.get(model, MOI.DualStatus())
        if !(dual_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT))
            error(
                "No dual solution is available. You must provide a point at " *
                "which to check feasibility. Or set dual_check = false.",
            )
        end
        data.dual_point = _last_dual_solution(model)
    end

    _analyze_primal!(model, data)
    _dual_model = nothing
    _map = nothing
    if dual_check
        dual_problem =
            Dualization.dualize(model, consider_constrained_variables = false)
        _dual_model = dual_problem.dual_model
        _map = dual_problem.primal_dual_map
        _analyze_dual!(model, _dual_model, _map, data)
        _analyze_complementarity!(model, data)
    end
    _analyze_objectives!(model, _dual_model, _map, data)
    sort!(data.primal, by = x -> abs(x.violation))
    sort!(data.dual, by = x -> abs(x.violation))
    sort!(data.complementarity, by = x -> abs(x.violation))
    return data
end

function _analyze_primal!(model, data)
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            func = MOI.get(model, MOI.ConstraintFunction(), con)
            failed = false
            val = MOI.Utilities.eval_variables(model, func) do var_idx
                if !haskey(data.primal_point, var_idx)
                    if data.skip_missing
                        failed = true
                        return NaN # nothing
                    else
                        error(
                            "Missing variable in primal point: $var_idx. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return data.primal_point[var_idx]
            end
            if failed
                continue
            end
            set = MOI.get(model, MOI.ConstraintSet(), con)
            dist = MOI.Utilities.distance_to_set(val, set)
            if dist > data.atol
                push!(data.primal, PrimalViolation(con, dist))
            end
        end
    end
    return
end

function _dual_point_to_dual_model_ref(
    primal_model,
    map::Dualization.PrimalDualMap,
    dual_point,
)
    new_dual_point = Dict{MOI.VariableIndex,Number}()
    dual_var_to_primal_con = Dict{MOI.VariableIndex,MOI.ConstraintIndex}()
    dual_con_to_primal_con = Dict{MOI.ConstraintIndex,MOI.ConstraintIndex}()
    for (F, S) in MOI.get(primal_model, MOI.ListOfConstraintTypesPresent())
        list = MOI.get(primal_model, MOI.ListOfConstraintIndices{F,S}())
        for primal_con in list
            dual_vars = Dualization._get_dual_variables(map, primal_con)
            val = get(dual_point, primal_con, nothing)
            if !isnothing(val)
                if length(dual_vars) != length(val)
                    error(
                        "The dual point entry for constraint $primal_con has " *
                        "length $(length(val)) but the dual variable " *
                        "length is $(length(dual_vars)).",
                    )
                end
                for (idx, dual_var) in enumerate(dual_vars)
                    new_dual_point[dual_var] = val[idx]
                end
            end
            for dual_var in dual_vars
                dual_var_to_primal_con[dual_var] = primal_con
            end
            dual_con = Dualization._get_dual_constraint(map, primal_con)
            if dual_con !== nothing
                dual_con_to_primal_con[dual_con] = primal_con
                # else
                #     if !(primal_con isa MOI.ConstraintIndex{MOI.VariableIndex,<:MOI.EqualTo} ||
                #         primal_con isa MOI.ConstraintIndex{MOI.VectorOfVariables,MOI.Zeros}
                #         SAF in EQ, etc...
                #) 
                #         error("Problem with dualization, see: $primal_con")
                #     end
            end
        end
    end
    primal_vars = MOI.get(primal_model, MOI.ListOfVariableIndices())
    dual_con_to_primal_vars =
        Dict{MOI.ConstraintIndex,Vector{MOI.VariableIndex}}()
    for primal_var in primal_vars
        dual_con, idx = Dualization._get_dual_constraint(map, primal_var)
        @assert idx == -1
        idx = max(idx, 1)
        if haskey(dual_con_to_primal_vars, dual_con)
            # TODO: this should never be hit because there will be no primal
            #       constrained variables.
            # vec = dual_con_to_primal_vars[dual_con]
            # if idx > length(vec)
            #     resize!(vec, idx)
            # end
            # vec[idx] = primal_var
        else
            vec = Vector{MOI.VariableIndex}(undef, idx)
            vec[idx] = primal_var
            dual_con_to_primal_vars[dual_con] = vec
        end
    end
    return new_dual_point,
    dual_var_to_primal_con,
    dual_con_to_primal_vars,
    dual_con_to_primal_con
end

function _analyze_dual!(model, dual_model, map, data)
    dual_point,
    dual_var_to_primal_con,
    dual_con_to_primal_vars,
    dual_con_to_primal_con =
        _dual_point_to_dual_model_ref(model, map, data.dual_point)
    types = MOI.get(dual_model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(dual_model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            func = MOI.get(dual_model, MOI.ConstraintFunction(), con)
            failed = false
            val = MOI.Utilities.eval_variables(dual_model, func) do var_idx
                if !haskey(dual_point, var_idx)
                    if data.skip_missing
                        failed = true
                        return NaN # nothing
                    else
                        primal_con = dual_var_to_primal_con[var_idx]
                        error(
                            "Missing data for dual of constraint: $primal_con. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return dual_point[var_idx]
            end
            if failed
                continue
            end
            set = MOI.get(dual_model, MOI.ConstraintSet(), con)
            dist = MOI.Utilities.distance_to_set(val, set)
            if dist > data.atol
                if haskey(dual_con_to_primal_vars, con)
                    vars = dual_con_to_primal_vars[con]
                    # TODO: this must be true because we dont consider
                    #       constrained variables in the dualization.
                    @assert length(vars) == 1
                    push!(data.dual, DualConstraintViolation(vars[], dist))
                else
                    con = dual_con_to_primal_con[con]
                    push!(
                        data.dual_convar,
                        DualConstrainedVariableViolation(con, dist),
                    )
                end
            end
        end
    end
    return
end

function _analyze_complementarity!(model, data)
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            func = MOI.get(model, MOI.ConstraintFunction(), con)
            failed = false
            val = MOI.Utilities.eval_variables(model, func) do var_idx
                if !haskey(data.primal_point, var_idx)
                    if data.skip_missing
                        failed = true
                        return NaN # nothing
                    else
                        error(
                            "Missing variable in primal point: $var_idx. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return data.primal_point[var_idx]
            end
            set = MOI.get(model, MOI.ConstraintSet(), con)
            val = val - _set_value(set)
            if failed
                continue
            end
            if !haskey(data.dual_point, con)
                if data.skip_missing
                    continue
                else
                    error(
                        "Missing dual value for constraint: $con. " *
                        "Set skip_missing = true to ignore this error.",
                    )
                end
            end
            if length(data.dual_point[con]) != length(val)
                error(
                    "The dual point entry for constraint $con has " *
                    "length $(length(data.dual_point[con])) but the primal " *
                    "constraint length is $(length(val)) .",
                )
            end
            comp_val = MOI.Utilities.set_dot(val, data.dual_point[con], set)
            if abs(comp_val) > data.atol
                push!(
                    data.complementarity,
                    ComplemetarityViolation(con, comp_val),
                )
            end
        end
    end
    return
end

# not needed because it would have stoped in dualization before
# function _set_value(set::MOI.AbstractScalarSet)
#     return 0.0
# end
# function _set_value(set::MOI.Interval)
#     error("Interval sets are not supported.")
#     return (set.lower, set.upper)
# end

function _set_value(set::MOI.AbstractVectorSet)
    return zeros(MOI.dimension(set))
end

function _set_value(set::MOI.LessThan)
    return set.upper
end

function _set_value(set::MOI.GreaterThan)
    return set.lower
end

function _set_value(set::MOI.EqualTo)
    return set.value
end

function _analyze_objectives!(model::MOI.ModelLike, dual_model, map, data)
    primal_status = MOI.get(model, MOI.PrimalStatus())
    dual_status = MOI.get(model, MOI.DualStatus())
    if data.primal_objective !== nothing
        obj_val_solver = data.primal_objective
    elseif primal_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
        obj_val_solver = MOI.get(model, MOI.ObjectiveValue())
    else
        obj_val_solver = nothing
    end

    if data.dual_objective !== nothing
        dual_obj_val_solver = data.dual_objective
    elseif dual_status in (MOI.FEASIBLE_POINT, MOI.NEARLY_FEASIBLE_POINT)
        dual_obj_val_solver = MOI.get(model, MOI.DualObjectiveValue())
    else
        dual_obj_val_solver = nothing
    end

    if dual_obj_val_solver !== nothing &&
       obj_val_solver !== nothing &&
       !isapprox(obj_val_solver, dual_obj_val_solver; atol = data.atol)
        push!(
            data.primal_dual_solver_mismatch,
            PrimalDualSolverMismatch(obj_val_solver, dual_obj_val_solver),
        )
    end

    obj_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj_func = MOI.get(model, MOI.ObjectiveFunction{obj_type}())
    obj_val = MOI.Utilities.eval_variables(model, obj_func) do var_idx
        if !haskey(data.primal_point, var_idx)
            if data.skip_missing
                return NaN # nothing
            else
                error(
                    "Missing variable in primal point: $var_idx. " *
                    "Set skip_missing = true to ignore this error.",
                )
            end
        end
        return data.primal_point[var_idx]
    end

    if obj_val_solver !== nothing &&
       !isapprox(obj_val, obj_val_solver; atol = data.atol)
        push!(
            data.primal_objective_mismatch,
            PrimalObjectiveMismatch(obj_val, obj_val_solver),
        )
    end

    if dual_model !== nothing && data.dual_point !== nothing
        dual_point, dual_var_to_primal_con, _, _ =
            _dual_point_to_dual_model_ref(model, map, data.dual_point)

        obj_type = MOI.get(dual_model, MOI.ObjectiveFunctionType())
        obj_func = MOI.get(dual_model, MOI.ObjectiveFunction{obj_type}())
        dual_obj_val =
            MOI.Utilities.eval_variables(dual_model, obj_func) do var_idx
                if !haskey(dual_point, var_idx)
                    if data.skip_missing
                        return NaN # nothing
                    else
                        primal_con = dual_var_to_primal_con[var_idx]
                        error(
                            "Missing data for dual of constraint: $primal_con. " *
                            "Set skip_missing = true to ignore this error.",
                        )
                    end
                end
                return dual_point[var_idx]
            end

        if dual_obj_val_solver !== nothing &&
           !isapprox(dual_obj_val, dual_obj_val_solver; atol = data.atol)
            push!(
                data.dual_objective_mismatch,
                DualObjectiveMismatch(dual_obj_val, dual_obj_val_solver),
            )
        end

        if !isapprox(obj_val, dual_obj_val; atol = data.atol) &&
           !isnan(dual_obj_val) &&
           !isnan(obj_val)
            push!(
                data.primal_dual_mismatch,
                PrimalDualMismatch(obj_val, dual_obj_val),
            )
        end
    end

    return
end

function _last_primal_solution(model::MOI.ModelLike)
    variables = MOI.get(model, MOI.ListOfVariableIndices())
    return Dict(v => MOI.get(model, MOI.VariablePrimal(), v) for v in variables)
end

function _last_dual_solution(model::MOI.ModelLike)
    ret = Dict{MOI.ConstraintIndex,Union{Number,Vector{<:Number}}}()
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        for con in list
            val = MOI.get(model, MOI.ConstraintDual(), con)
            ret[con] = val
        end
    end
    return ret
end

function _can_dualize(model::MOI.ModelLike)
    types = MOI.get(model, MOI.ListOfConstraintTypesPresent())

    for (F, S) in types
        if !Dualization.supported_constraint(F, S)
            return false
        end
    end

    F = MOI.get(model, MOI.ObjectiveFunctionType())

    if !Dualization.supported_objective(F)
        return false
    end

    sense = MOI.get(model, MOI.ObjectiveSense())
    if sense == MOI.FEASIBILITY_SENSE
        return false
    end

    return true
end
