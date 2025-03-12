# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

struct InfeasibleBounds{T}
    variable::VariableRef
    lb::T
    ub::T
end

struct InfeasibleIntegrality{T}
    variable::VariableRef
    lb::T
    ub::T
    set::Union{MOI.Integer,MOI.ZeroOne}#, MOI.Semicontinuous{T}, MOI.Semiinteger{T}}
end

struct InfeasibleConstraintRange{T}
    constraint::ConstraintRef
    lb::T
    ub::T
    set::Union{MOI.EqualTo{T},MOI.LessThan{T},MOI.GreaterThan{T}}
end

struct IrreducibleInfeasibleSubset
    constraint::Vector{ConstraintRef}
end

Base.@kwdef mutable struct InfeasibilityData
    infeasible_bounds::Vector{InfeasibleBounds} = InfeasibleBounds[]
    infeasible_integrality::Vector{InfeasibleIntegrality} =
        InfeasibleIntegrality[]

    constraint_range::Vector{InfeasibleConstraintRange} =
        InfeasibleConstraintRange[]

    iis::Vector{IrreducibleInfeasibleSubset} = IrreducibleInfeasibleSubset[]
end

function infeasibility_analysis(model::Model; optimizer = nothing)
    T = Float64

    out = InfeasibilityData()

    variables = Dict{VariableRef,Interval{T}}()

    # first layer of infeasibility analysis is bounds consistency
    bounds_consistent = true
    for var in JuMP.all_variables(model)
        lb = if JuMP.has_lower_bound(var)
            JuMP.lower_bound(var)
        else
            -Inf
        end
        ub = if JuMP.has_upper_bound(var)
            JuMP.upper_bound(var)
        else
            Inf
        end
        if lb > ub
            push!(out.infeasible_bounds, InfeasibleBounds(var, lb, ub))
            bounds_consistent = false
        else
            variables[var] = Interval(lb, ub)
        end
        if JuMP.is_integer(var)
            if abs(ub - lb) < 1 && ceil(ub) == ceil(lb)
                push!(
                    out.infeasible_integrality,
                    InfeasibleIntegrality(var, lb, ub, MOI.Integer()),
                )
                bounds_consistent = false
            end
        end
        if JuMP.is_binary(var)
            if lb > 0 && ub < 1
                push!(
                    out.infeasible_integrality,
                    InfeasibleIntegrality(var, lb, ub, MOI.ZeroOne()),
                )
                bounds_consistent = false
            end
        end
    end
    # check PSD diagonal >= 0 ?
    # other cones?
    if !bounds_consistent
        return out
    end

    # second layer of infeasibility analysis is constraint range analysis
    range_consistent = true
    for (F, S) in JuMP.list_of_constraint_types(model)
        F != JuMP.GenericAffExpr{T,JuMP.VariableRef} && continue
        # TODO: handle quadratics
        !(S in (MOI.EqualTo{T}, MOI.LessThan{T}, MOI.GreaterThan{T})) &&
            continue
        for con in JuMP.all_constraints(model, F, S)
            con_obj = JuMP.constraint_object(con)
            interval = JuMP.value(x -> variables[x], con_obj.func)
            if con_obj.set isa MOI.EqualTo{T}
                rhs = con_obj.set.value
                if interval.lo > rhs || interval.hi < rhs
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange(
                            con,
                            interval.lo,
                            interval.hi,
                            con_obj.set,
                        ),
                    )
                    range_consistent = false
                end
            elseif con_obj.set isa MOI.LessThan{T}
                rhs = con_obj.set.upper
                if interval.lo > rhs
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange(
                            con,
                            interval.lo,
                            interval.hi,
                            con_obj.set,
                        ),
                    )
                    range_consistent = false
                end
            elseif con_obj.set isa MOI.GreaterThan{T}
                rhs = con_obj.set.lower
                if interval.hi < rhs
                    push!(
                        out.constraint_range,
                        InfeasibleConstraintRange(
                            con,
                            interval.lo,
                            interval.hi,
                            con_obj.set,
                        ),
                    )
                    range_consistent = false
                end
            end
        end
    end

    if !range_consistent
        return out
    end

    # check if there is a optimizer
    # third layer is an IIS resolver
    if optimizer === nothing
        println("iis resolver cannot continue because no optimizer is provided")
        return out
    end
    iis = iis_elastic_filter(model, optimizer)
    # for now, only one iis is computed
    push!(out.iis, IrreducibleInfeasibleSubset(iis))

    return out
end

function iis_elastic_filter(original_model::Model, optimizer)

    # if JuMP.termination_status(original_model) == MOI.OPTIMIZE_NOT_CALLED
    #     println("iis resolver cannot continue because model is not optimized")
    #     # JuMP.optimize!(original_model)
    # end

    status = JuMP.termination_status(original_model)
    if status != MOI.INFEASIBLE
        println(
            "iis resolver cannot continue because model is found to be $(status) by the solver",
        )
        return
    end

    model, reference_map = JuMP.copy_model(original_model)
    JuMP.set_optimizer(model, optimizer)
    JuMP.set_silent(model)
    # TODO handle ".ext" to avoid warning

    constraint_to_affine = JuMP.relax_with_penalty!(model, default = 1.0)
    # might need to do somehting related to integers / binary

    JuMP.optimize!(model)

    max_iterations = length(constraint_to_affine)

    tolerance = 1e-5

    for _ in 1:max_iterations
        if JuMP.termination_status(model) == MOI.INFEASIBLE
            break
        end
        for (con, func) in constraint_to_affine
            if length(func.terms) == 1
                var = collect(keys(func.terms))[1]
                if value(var) > tolerance
                    fix(var, 0.0; force = true)
                    # or delete(model, var)
                    delete!(constraint_to_affine, con)
                end
            elseif length(func.terms) == 2
                var = collect(keys(func.terms))
                coef1 = func.terms[var[1]]
                coef2 = func.terms[var[2]]
                if value(var1) > tolerance && value(var2) > tolerance
                    error("IIS failed due numerical instability")
                elseif value(var[1]) > tolerance
                    fix(var[1], 0.0; force = true)
                    # or delete(model, var1)
                    delete!(constraint_to_affine, con)
                    constraint_to_affine[con] = coef2 * var[2]
                elseif value(var[2]) > tolerance
                    fix(var[2], 0.0; force = true)
                    # or delete(model, var2)
                    delete!(constraint_to_affine, con)
                    constraint_to_affine[con] = coef1 * var[1]
                end
            else
                println(
                    "$con and relaxing function with more than two terms: $func",
                )
            end
            JuMP.optimize!(model)
        end
    end

    pre_iis = Set(keys(constraint_to_affine))
    iis = JuMP.ConstraintRef[]
    for con in pre_iis
        push!(iis, reference_map[con])
    end

    return iis
end
