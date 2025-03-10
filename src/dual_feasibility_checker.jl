# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _last_dual_solution(model::GenericModel{T}) where T
    if !has_duals(model)
        error(
            "No dual solution is available. You must provide a point at " *
            "which to check feasibility.",
        )
    end
    constraint_list =
        all_constraints(model; include_variable_in_set_constraints = true)
    ret = Dict{JuMP.ConstraintRef,Vector{T}}()
    for c in constraint_list
        _dual = JuMP.dual(c)
        if typeof(_dual) == Vector{T}
            ret[c] = _dual
        else
            ret[c] = T[_dual]
        end
    end
    return ret
end

"""
    dual_feasibility_report(
        model::GenericModel{T},
        point::AbstractDict{GenericVariableRef{T},T} = _last_dual_solution(model),
        atol::T = zero(T),
        skip_missing::Bool = false,
    )::Dict{Any,T}

Given a dictionary `point`, which maps variables to dual values, return a
dictionary whose keys are the constraints with an infeasibility greater than the
supplied tolerance `atol`. The value corresponding to each key is the respective
infeasibility. Infeasibility is defined as the distance between the dual
value of the constraint (see `MOI.ConstraintDual`) and the nearest point by
Euclidean distance in the corresponding set.

## Notes

 * If `skip_missing = true`, constraints containing variables that are not in
   `point` will be ignored.
 * If `skip_missing = false` and a partial dual solution is provided, an error
   will be thrown.
 * If no point is provided, the dual solution from the last time the model was
   solved is used.

## Example

```jldoctest
julia> model = Model();

julia> @variable(model, 0.5 <= x <= 1);

julia> dual_feasibility_report(model, Dict(x => 0.2))
XXXX
```
"""
function dual_feasibility_report(
    model::GenericModel{T},
    point::AbstractDict = _last_dual_solution(model);
    atol::T = zero(T),
    skip_missing::Bool = false,
) where {T}
    if JuMP.num_nonlinear_constraints(model) > 0
        error(
            "Nonlinear constraints are not supported. " *
            "Use `dual_feasibility_report` instead.",
        )
    end
    if !skip_missing
        constraint_list =
            all_constraints(model; include_variable_in_set_constraints = true)
        for c in constraint_list
            if !haskey(point, c)
                error(
                    "point does not contain a dual for constraint $c. Provide " *
                    "a dual, or pass `skip_missing = true`.",
                )
            end
        end
    end
    dual_model = _dualize2(model)
    primal_con_dual_var = dual_model.ext[:dualization_primal_dual_map].primal_con_dual_var

    # point is a:
    # dict mapping primal constraints to (dual) values
    # we need to convert it to a:
    # dict mapping the dual model variables to these (dual) values

    primal_con_dual_convar = dual_model.ext[:dualization_primal_dual_map].primal_con_dual_con

    dual_point = Dict{GenericVariableRef{T},T}()
    for (jump_con, val) in point
        moi_con = JuMP.index(jump_con)
        if haskey(primal_con_dual_var, moi_con)
            vec_vars = primal_con_dual_var[moi_con]
            for (i, moi_var) in enumerate(vec_vars)
                jump_var = JuMP.VariableRef(dual_model, moi_var)
                dual_point[jump_var] = val[i]
            end
        elseif haskey(primal_con_dual_convar, moi_con)
            moi_convar = primal_con_dual_convar[moi_con]
            jump_var = JuMP.VariableRef(dual_model, MOI.VariableIndex(moi_convar.value))
            dual_point[jump_var] = val
        else
            # careful with the case where bounds do not become variables
            # error("Constraint $jump_con is not associated with a variable in the dual model.")
        end
    end

    dual_con_to_violation = JuMP.primal_feasibility_report(
        dual_model,
        dual_point;
        atol = atol,
        skip_missing = skip_missing,
    )

    # some dual model constraints are associated with primal model variables (primal_con_dual_var)
    # if variable is free (almost a primal con = ConstraintIndex{MOI.VariableIndex, MOI.Reals})
    primal_var_dual_con = dual_model.ext[:dualization_primal_dual_map].primal_var_dual_con
    # if variable is bounded
    primal_convar_dual_con = dual_model.ext[:dualization_primal_dual_map].constrained_var_dual
    # other dual model constraints (bounds) are associated with primal model constraints (non-bounds)
    primal_con_dual_convar = dual_model.ext[:dualization_primal_dual_map].primal_con_dual_con

    dual_con_primal_all = _build_dual_con_primal_all(
        primal_var_dual_con,
        primal_convar_dual_con,
        primal_con_dual_convar,
    )

    ret = _fix_ret(dual_con_to_violation, model, dual_con_primal_all)

    return ret
end

function _build_dual_con_primal_all(
    primal_var_dual_con,
    primal_convar_dual_con,
    primal_con_dual_con,
)
    # MOI.VariableIndex here represents MOI.ConstraintIndex{MOI.VariableIndex, MOI.Reals}
    dual_con_primal_all = Dict{MOI.ConstraintIndex, Union{MOI.ConstraintIndex, MOI.VariableIndex}}()
    for (primal_var, dual_con) in primal_var_dual_con
        dual_con_primal_all[dual_con] = primal_var
    end
    for (primal_con, dual_con) in primal_convar_dual_con
        dual_con_primal_all[dual_con] = primal_con
    end
    for (primal_con, dual_con) in primal_con_dual_con
        dual_con_primal_all[dual_con] = primal_con
    end
    return dual_con_primal_all
end

function _fix_ret(pre_ret, primal_model::GenericModel{T}, dual_con_primal_all) where {T}
    ret = Dict{Union{JuMP.ConstraintRef,JuMP.VariableRef},Union{T,Vector{T}}}()
    for (jump_dual_con, val) in pre_ret
        # v is a variable in the dual jump model
        # we need the associated cosntraint in the primal jump model
        moi_dual_con = JuMP.index(jump_dual_con)
        moi_primal_something = dual_con_primal_all[moi_dual_con]
        if moi_primal_something isa MOI.VariableIndex
            # variable in the dual model
            # constraint in the primal model
            jump_primal_var = JuMP.VariableRef(primal_model, moi_primal_something)
            # ret[jump_primal_var] = T[val]
            ret[jump_primal_var] = val
        else
            # constraint in the primal model
            jump_primal_con = JuMP.constraint_ref_with_index(primal_model, moi_primal_something)
            # if val isa Vector
            #     ret[jump_primal_con] = val
            # else
            #     ret[jump_primal_con] = T[val]
            # end
            ret[jump_primal_con] = val
        end
    end
    return ret
end

function _add_with_resize!(vec, val, i)
    if i > length(vec)
        resize!(vec, i)
    end
    vec[i] = val
end

"""
    dual_feasibility_report(
        point::Function,
        model::GenericModel{T};
        atol::T = zero(T),
        skip_missing::Bool = false,
    ) where {T}

A form of `dual_feasibility_report` where a function is passed as the first
argument instead of a dictionary as the second argument.

## Example

```jldoctest
julia> model = Model();

julia> @variable(model, 0.5 <= x <= 1, start = 1.3); TODO

julia> dual_feasibility_report(model) do v
           return dual_start_value(v)
       end
Dict{Any, Float64} with 1 entry:
  x ≤ 1 => 0.3 TODO
```
"""
# probablye remove this method
function dual_feasibility_report(
    point::Function,
    model::GenericModel{T};
    atol::T = zero(T),
    skip_missing::Bool = false,
) where {T}
    if JuMP.num_nonlinear_constraints(model) > 0
        error(
            "Nonlinear constraints are not supported. " *
            "Use `dual_feasibility_report` instead.",
        )
    end
    if !skip_missing
        constraint_list =
            all_constraints(model; include_variable_in_set_constraints = false)
        for c in constraint_list
            if !haskey(point, c)
                error(
                    "point does not contain a dual for constraint $c. Provide " *
                    "a dual, or pass `skip_missing = true`.",
                )
            end
        end
    end
    dual_model = _dualize2(model)
    map = dual_model.ext[:dualization_primal_dual_map].primal_con_dual_var

    dual_var_primal_con = _reverse_primal_con_dual_var_map(map)

    function dual_point(jump_dual_var::GenericVariableRef{T})
        # v is a variable in the dual jump model
        # we need the associated cosntraint in the primal jump model
        moi_dual_var = JuMP.index(jump_dual_var)
        moi_primal_con, i = dual_var_primal_con[moi_dual_var]
        jump_primal_con = JuMP.constraint_ref_with_index(model, moi_primal_con)
        pre_point = point(jump_primal_con)
        if ismissing(pre_point)
            if !skip_missing
                error(
                    "point does not contain a dual for constraint $jump_primal_con. Provide " *
                    "a dual, or pass `skip_missing = true`.",
                )
            else
                return missing
            end
        end
        return point(jump_primal_con)[i]
    end

    dual_con_to_violation = JuMP.primal_feasibility_report(
        dual_point,
        dual_model;
        atol = atol,
        skip_missing = skip_missing,
    )

    # some dual model constraints are associated with primal model variables (primal_con_dual_var)
    # if variable is free
    primal_var_dual_con = dual_model.ext[:dualization_primal_dual_map].primal_var_dual_con
    # if variable is bounded
    primal_convar_dual_con = dual_model.ext[:dualization_primal_dual_map].constrained_var_dual
    # other dual model constraints (bounds) are associated with primal model constraints (non-bounds)
    primal_con_dual_con = dual_model.ext[:dualization_primal_dual_map].primal_con_dual_con

    dual_con_primal_all = _build_dual_con_primal_all(
        primal_var_dual_con,
        primal_convar_dual_con,
        primal_con_dual_con,
    )

    ret = _fix_ret(dual_con_to_violation, model, dual_con_primal_all)

    return ret
end

function _reverse_primal_con_dual_var_map(primal_con_dual_var)
    dual_var_primal_con =
    Dict{MOI.VariableIndex,Tuple{MOI.ConstraintIndex,Int}}()
    for (moi_con, vec_vars) in primal_con_dual_var
        for (i, moi_var) in enumerate(vec_vars)
            dual_var_primal_con[moi_var] = (moi_con, i)
        end
    end
    return dual_var_primal_con
end

function _dualize2(
    model::JuMP.Model,
    optimizer_constructor = nothing;
    kwargs...,
)
    mode = JuMP.mode(model)
    if mode != JuMP.AUTOMATIC
        error("Dualization does not support solvers in $(mode) mode")
    end
    dual_model = JuMP.Model()
    dual_problem = Dualization.DualProblem(JuMP.backend(dual_model))
    Dualization.dualize(JuMP.backend(model), dual_problem; kwargs...)
    Dualization._fill_obj_dict_with_variables!(dual_model)
    Dualization._fill_obj_dict_with_constraints!(dual_model)
    if optimizer_constructor !== nothing
        JuMP.set_optimizer(dual_model, optimizer_constructor)
    end
    dual_model.ext[:dualization_primal_dual_map] = dual_problem.primal_dual_map
    return dual_model
end
