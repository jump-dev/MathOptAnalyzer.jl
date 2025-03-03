# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

Base.@kwdef mutable struct CoefficientsData

    number_of_variables::Int = 0
    number_of_constraints::Int = 0

    constraint_info::Vector{Tuple{DataType, DataType, Int}} = Tuple{DataType, DataType, Int}[]

    matrix_nnz::Int = 0
    
    matrix_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    bounds_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    rhs_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)
    objective_range::Vector{Float64} = sizehint!(Float64[1.0, 1.0], 2)

    threshold_dense_row::Float64 = 0.10
    threshold_small_coefficient::Float64 = 1e-5
    threshold_large_coefficient::Float64 = 1e+5

    bound_rows::Vector{ConstraintRef} = ConstraintRef[]
    dense_rows::Vector{Tuple{ConstraintRef, Int}} = Tuple{ConstraintRef, Int}[]
    small_coefficients::Vector{Tuple{ConstraintRef, VariableRef, Float64}} = Tuple{ConstraintRef, VariableRef, Float64}[]
    large_coefficients::Vector{Tuple{ConstraintRef, VariableRef, Float64}} = Tuple{ConstraintRef, VariableRef, Float64}[]

end

function _update_range(range::Vector{Float64}, value::Number)
    if !(value ≈ 0.0)
        range[1] = min(range[1], abs(value))
        range[2] = max(range[2], abs(value))
        return true
    end
    return false
end

function _get_data(data, ref::ConstraintRef, func::JuMP.GenericAffExpr)
    if length(func.terms) == 1
        if first(values(func.terms)) ≈ 1.0
            push!(data.bound_rows, ref)
            data.matrix_nnz += 1
            return
        end
    end
    nnz = 0
    for (variable, coefficient) in func.terms
        nnz += _update_range(data.matrix_range, coefficient)
        if abs(coefficient) < data.threshold_small_coefficient
            push!(data.small_coefficients, (ref, variable, coefficient))
        elseif abs(coefficient) > data.threshold_large_coefficient
            push!(data.large_coefficients, (ref, variable, coefficient))
        end
    end
    if nnz / data.number_of_variables > data.threshold_dense_row && nnz > 100
        push!(data.dense_rows, (ref, nnz))
    end
    data.matrix_nnz += nnz
    return
end

function _update_range(range::Vector, func::JuMP.GenericAffExpr)
    _update_range(range, func.constant)
    return true
end

function _get_data(data, func::Vector{JuMP.GenericAffExpr}, set)
    for f in func
        _update_range(data, f, set)
    end
    return true
end

function _get_data(data, func::JuMP.GenericAffExpr, set)
    _update_range(data.rhs_range, func.constant)
    return true
end

function _get_data(data, func::JuMP.GenericAffExpr, set::MOI.LessThan)
    _update_range(data.rhs_range, set.upper - func.constant)
    return true
end

function _get_data(data, func::JuMP.GenericAffExpr, set::MOI.GreaterThan)
    _update_range(data.rhs_range, set.lower - func.constant)
    return true
end

function _get_data(data, func::JuMP.GenericAffExpr, set::MOI.EqualTo)
    _update_range(data.rhs_range, set.value - func.constant)
    return true
end

function _get_data(data, func::JuMP.GenericAffExpr, set::MOI.Interval)
    _update_range(data.rhs_range, set.upper - func.constant)
    _update_range(data.rhs_range, set.lower - func.constant)
    return true
end

# Default fallback for unsupported constraints.
_update_range(data, func, set) = false

function coefficient_analysis(model::JuMP.Model)
    data = CoefficientsData()
    data.number_of_variables = JuMP.num_variables(model)
    data.number_of_constraints = JuMP.num_constraints(model, count_variable_in_set_constraints = false)
    _update_range(data.objective_range, JuMP.objective_function(model))
    for var in JuMP.all_variables(model)
        if JuMP.has_lower_bound(var)
            _update_range(data.bounds_range, JuMP.lower_bound(var))
        end
        if JuMP.has_upper_bound(var)
            _update_range(data.bounds_range, JuMP.upper_bound(var))
        end
    end
    for (F, S) in JuMP.list_of_constraint_types(model)
        n = JuMP.num_constraints(model, F, S)
        if n > 0
            push!(data.constraint_info, (F, S, n))
        end
        F == JuMP.VariableRef && continue
        F == Vector{JuMP.VariableRef} && continue
        for con in JuMP.all_constraints(model, F, S)
            con_obj = JuMP.constraint_object(con)
            _get_data(data, con, con_obj.func)
            _get_data(data, con_obj.func, con_obj.set)
        end
    end
    sort!(data.dense_rows, by = x -> x[2], rev = true)
    sort!(data.small_coefficients, by = x -> abs(x[3]))
    sort!(data.large_coefficients, by = x -> abs(x[3]), rev = true)
    return data
end

# printing

_print_value(x::Real) = Printf.@sprintf("%1.0e", x)

function _stringify_bounds(bounds::Vector{Float64})
    lower = bounds[1] < Inf ? _print_value(bounds[1]) : "0e+00"
    upper = bounds[2] > -Inf ? _print_value(bounds[2]) : "0e+00"
    return string("[", lower, ", ", upper, "]")
end

function _print_coefficients(
    io::IO,
    name::String,
    data,
    range,
    warnings::Vector{Tuple{String,String}},
)
    println(
        io,
        "    ",
        rpad(string(name, " range"), 17),
        _stringify_bounds(range),
    )
    if range[1] < data.threshold_small_coefficient
        push!(warnings, (name, "small"))
    end
    if range[2] > data.threshold_large_coefficient
        push!(warnings, (name, "large"))
    end
    return
end

function _print_numerical_stability_report(
    io::IO,
    data::CoefficientsData;
    warn::Bool = true,
    verbose::Bool = true,
    max_list::Int = 10,
)
    println(io, "Numerical stability report:")
    println(io, "  Number of variables: ", data.number_of_variables)
    println(io, "  Number of constraints: ", data.number_of_constraints)
    println(io, "  Number of nonzeros in matrix: ", data.matrix_nnz)
    println(io, "  Threshold for dense rows: ", data.threshold_dense_row)
    println(io, "  Threshold for small coefficients: ", data.threshold_small_coefficient)
    println(io, "  Threshold for large coefficients: ", data.threshold_large_coefficient)

    println(io, "  Coefficient ranges:")
    warnings = Tuple{String, String}[]
    _print_coefficients(io, "matrix", data, data.matrix_range, warnings)
    _print_coefficients(io, "objective", data, data.objective_range, warnings)
    _print_coefficients(io, "bounds", data, data.bounds_range, warnings)
    _print_coefficients(io, "rhs", data, data.rhs_range, warnings)

    # types
    println(io, "  Constraint types:")
    for (F, S, n) in data.constraint_info
        println(io, "    * ", F, "-", S, ": ", n)
    end

    # rows that should be bounds
    println(io, "  Bound rows: ", length(data.bound_rows))
    if verbose
        c = 0
        for ref in data.bound_rows
            println(io, "    * ", ref)
            c += 1
            if c >= max_list
                break
            end
        end
    end

    println(io, "  Dense constraints: ", length(data.dense_rows))
    println(io, "  Small coefficients: ", length(data.small_coefficients))
    println(io, "  Large coefficients: ", length(data.large_coefficients))

    if verbose
        println(io, "")
        println(io, "  Dense constraints:")
        c = 0
        for (ref, nnz) in data.dense_rows
            println(io, "    * ", ref, ": ", nnz)
            c += 1
            if c >= max_list
                break
            end
        end
        println(io, "")
        println(io, "  Small coefficients:")
        c = 0
        for (ref, var, coeff) in data.small_coefficients
            println(io, "    * ", ref, ": ", var, " -> ", coeff)
            c += 1
            if c >= max_list
                break
            end
        end
        println(io, "")
        println(io, "  Large coefficients:")
        c = 0
        for (ref, var, coeff) in data.large_coefficients
            println(io, "    * ", ref, ": ", var, " -> ", coeff)
            c += 1
            if c >= max_list
                break
            end
        end
    end

    if warn && !isempty(warnings)
        println(io, "\nWARNING: numerical stability issues detected")
        for (name, sense) in warnings
            println(io, "  - $(name) range contains $(sense) coefficients")
        end
        println(
            io,
            "Very large or small absolute values of coefficients\n",
            "can cause numerical stability issues. Consider\n",
            "reformulating the model.",
        )
    end
    return
end

function Base.show(io::IO, data::CoefficientsData; verbose::Bool = false)
    _print_numerical_stability_report(io, data, warn = true, verbose = verbose)
    return
end

# TODO add names in the output
# TODO add lists for rhs, bounds and obj coefs
# TODO analyse quadratics
# check variable that are not in constraints
# check start poitn in bounds