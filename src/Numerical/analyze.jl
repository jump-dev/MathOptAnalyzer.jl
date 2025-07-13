# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

"""
    analyze(model::Model; threshold_dense_fill_in = 0.10, threshold_dense_entries = 1000, threshold_small = 1e-5, threshold_large = 1e+5)

Analyze the coefficients of a model.

"""
function MathOptAnalyzer.analyze(
    ::Analyzer,
    model::MOI.ModelLike,
    ;
    threshold_dense_fill_in::Float64 = 0.10,
    threshold_dense_entries::Int = 1000,
    threshold_small::Float64 = 1e-5,
    threshold_large::Float64 = 1e+5,
)
    data = Data()
    data.threshold_dense_fill_in = threshold_dense_fill_in
    data.threshold_dense_entries = threshold_dense_entries
    data.threshold_small = threshold_small
    data.threshold_large = threshold_large

    # initialize simples data
    data.sense = MOI.get(model, MOI.ObjectiveSense())
    data.number_of_variables = MOI.get(model, MOI.NumberOfVariables())
    sizehint!(data.variables_in_constraints, data.number_of_variables)

    # objective pass
    objective_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj_func = MOI.get(model, MOI.ObjectiveFunction{objective_type}())
    _get_objective_data(data, obj_func)

    # constraints pass
    data.number_of_constraints = 0
    list_of_constraint_types =
        MOI.get(model, MOI.ListOfConstraintTypesPresent())
    for (F, S) in list_of_constraint_types
        list = MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        n = length(list)
        data.number_of_constraints += n
        if n > 0
            push!(data.constraint_info, (F, S, n))
        end
        for con in list
            func = MOI.get(model, MOI.ConstraintFunction(), con)
            set = MOI.get(model, MOI.ConstraintSet(), con)
            _get_constraint_matrix_data(data, con, func)
            _get_constraint_data(data, con, func, set)
        end
    end
    # second pass on variables after constraint pass
    # variable index constraints are not counted in the constraints pass
    list_of_variables = MOI.get(model, MOI.ListOfVariableIndices())
    for var in list_of_variables
        if !(var in data.variables_in_constraints)
            push!(
                data.variables_not_in_constraints,
                VariableNotInConstraints(var),
            )
        end
    end
    sort!(data.dense_rows, by = x -> x.nnz, rev = true)
    sort!(data.matrix_small, by = x -> abs(x.coefficient))
    sort!(data.matrix_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.bounds_small, by = x -> abs(x.coefficient))
    sort!(data.bounds_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.rhs_small, by = x -> abs(x.coefficient))
    sort!(data.rhs_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.matrix_quadratic_small, by = x -> abs(x.coefficient))
    sort!(data.matrix_quadratic_large, by = x -> abs(x.coefficient), rev = true)
    # objective
    sort!(data.objective_small, by = x -> abs(x.coefficient))
    sort!(data.objective_large, by = x -> abs(x.coefficient), rev = true)
    sort!(data.objective_quadratic_small, by = x -> abs(x.coefficient))
    sort!(
        data.objective_quadratic_large,
        by = x -> abs(x.coefficient),
        rev = true,
    )
    return data
end

function _update_range(range::Vector{Float64}, value::Number)
    range[1] = min(range[1], abs(value))
    range[2] = max(range[2], abs(value))
    return 1
end

function _get_objective_data(data, func::MOI.VariableIndex)
    return
end

function _get_objective_data(data, func::MOI.ScalarAffineFunction)
    nnz = 0
    for term in func.terms
        variable = term.variable
        coefficient = term.coefficient
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.objective_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.objective_small,
                SmallObjectiveCoefficient(variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.objective_large,
                LargeObjectiveCoefficient(variable, coefficient),
            )
        end
    end
    return
end

function _get_objective_data(
    data,
    func::MOI.ScalarQuadraticFunction{T},
) where {T}
    _get_objective_data(
        data,
        MOI.ScalarAffineFunction(func.affine_terms, func.constant),
    )
    nnz = 0
    for term in func.quadratic_terms
        coefficient = term.coefficient
        v1 = term.variable_1
        v2 = term.variable_2
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.objective_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.objective_quadratic_small,
                SmallObjectiveQuadraticCoefficient(v1, v2, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.objective_quadratic_large,
                LargeObjectiveQuadraticCoefficient(v1, v2, coefficient),
            )
        end
    end
    data.has_quadratic_objective = true
    if data.sense == MOI.MAX_SENSE
        if !_quadratic_vexity(func, -1)
            push!(data.nonconvex_objective, NonconvexQuadraticObjective())
        end
    elseif data.sense == MOI.MIN_SENSE
        if !_quadratic_vexity(func, 1)
            push!(data.nonconvex_objective, NonconvexQuadraticObjective())
        end
    end
    return
end

function _quadratic_vexity(func::MOI.ScalarQuadraticFunction, sign::Int)
    variables = Set{MOI.VariableIndex}()
    sizehint!(variables, 2 * length(func.quadratic_terms))
    for term in func.quadratic_terms
        push!(variables, term.variable_1)
        push!(variables, term.variable_2)
    end
    var_map = Dict{MOI.VariableIndex,Int}()
    for (idx, var) in enumerate(variables)
        var_map[var] = idx
    end
    matrix = zeros(length(variables), length(variables))
    for term in func.quadratic_terms
        coefficient = term.coefficient
        v1 = term.variable_1
        v2 = term.variable_2
        matrix[var_map[v1], var_map[v2]] += sign * coefficient / 2
        if v1 != v2
            matrix[var_map[v2], var_map[v1]] += sign * coefficient / 2
        end
    end
    ret = LinearAlgebra.cholesky!(
        LinearAlgebra.Symmetric(matrix),
        LinearAlgebra.RowMaximum(),
        check = false,
    )
    return LinearAlgebra.issuccess(ret)
end

function _quadratic_vexity(func::MOI.VectorQuadraticFunction{T}, sign) where {T}
    n = MOI.output_dimension(func)
    quadratic_terms_vector = [MOI.ScalarQuadraticTerm{T}[] for i in 1:n]
    for term in func.quadratic_terms
        index = term.output_index
        push!(quadratic_terms_vector[index], term.scalar_term)
    end
    for i in 1:n
        if length(quadratic_terms_vector[i]) == 0
            continue
        end
        if !_quadratic_vexity(
            MOI.ScalarQuadraticFunction{T}(
                quadratic_terms_vector[i],
                MOI.ScalarAffineTerm{T}[],
                zero(T),
            ),
            sign,
        )
            return false
        end
    end
    return true
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.ScalarAffineFunction;
    ignore_extras = false,
)
    if length(func.terms) == 1
        coefficient = func.terms[1].coefficient
        if !ignore_extras && isapprox(coefficient, 1.0)
            # TODO: do this in the vector case
            push!(data.bound_rows, VariableBoundAsConstraint(ref))
            data.matrix_nnz += 1
            # in this case we do not count that the variable is in a constraint
            return
        end
    end
    nnz = 0
    for term in func.terms
        variable = term.variable
        coefficient = term.coefficient
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.matrix_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_small,
                SmallMatrixCoefficient(ref, variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_large,
                LargeMatrixCoefficient(ref, variable, coefficient),
            )
        end
        push!(data.variables_in_constraints, variable)
    end
    if nnz == 0
        if !ignore_extras
            push!(data.empty_rows, EmptyConstraint(ref))
        end
        return
    end
    if nnz / data.number_of_variables > data.threshold_dense_fill_in &&
       nnz > data.threshold_dense_entries
        push!(data.dense_rows, DenseConstraint(ref, nnz))
    end
    data.matrix_nnz += nnz
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.ScalarQuadraticFunction{T},
) where {T}
    nnz = 0
    for term in func.quadratic_terms
        v1 = term.variable_1
        v2 = term.variable_2
        coefficient = term.coefficient
        if iszero(coefficient)
            continue
        end
        nnz += _update_range(data.matrix_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_quadratic_small,
                SmallMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_quadratic_large,
                LargeMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        end
        push!(data.variables_in_constraints, v1)
        push!(data.variables_in_constraints, v2)
    end
    data.has_quadratic_constraints = true
    _get_constraint_matrix_data(
        data,
        ref,
        MOI.ScalarAffineFunction{T}(func.affine_terms, func.constant),
        ignore_extras = nnz > 0,
    )
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VectorAffineFunction{T},
) where {T}
    for term in func.terms
        variable = term.scalar_term.variable
        coefficient = term.scalar_term.coefficient
        # index = term.output_index
        if iszero(coefficient)
            continue
        end
        _update_range(data.matrix_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_small,
                SmallMatrixCoefficient(ref, variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_large,
                LargeMatrixCoefficient(ref, variable, coefficient),
            )
        end
        push!(data.variables_in_constraints, variable)
    end
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VectorQuadraticFunction{T},
) where {T}
    for term in func.quadratic_terms
        v1 = term.scalar_term.variable_1
        v2 = term.scalar_term.variable_2
        coefficient = term.scalar_term.coefficient
        if iszero(coefficient)
            continue
        end
        _update_range(data.matrix_quadratic_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.matrix_quadratic_small,
                SmallMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.matrix_quadratic_large,
                LargeMatrixQuadraticCoefficient(ref, v1, v2, coefficient),
            )
        end
        push!(data.variables_in_constraints, v1)
        push!(data.variables_in_constraints, v2)
    end
    _get_constraint_matrix_data(
        data,
        ref,
        MOI.VectorAffineFunction{T}(func.affine_terms, func.constants),
        # ignore_extras = nnz > 0,
    )
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VariableIndex,
)
    # push!(data.variables_in_constraints, func)
    return
end

function _get_constraint_matrix_data(
    data,
    ref::MOI.ConstraintIndex,
    func::MOI.VectorOfVariables,
)
    if length(func.variables) == 1
        return
    end
    for var in func.variables
        push!(data.variables_in_constraints, var)
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::Union{MOI.ScalarAffineFunction,MOI.ScalarQuadraticFunction},
    set,
)
    coefficient = func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::Union{MOI.VectorAffineFunction,MOI.VectorQuadraticFunction},
    set,
)
    coefficients = func.constants
    for i in eachindex(coefficients)
        coefficient = coefficients[i]
        if iszero(coefficient)
            continue
        end
        _update_range(data.rhs_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
        elseif abs(coefficient) > data.threshold_large
            push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
        end
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarQuadraticFunction{T},
    set::MOI.LessThan{T},
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.ScalarAffineFunction{T}(func.affine_terms, func.constant),
        set,
    )
    if !_quadratic_vexity(func, 1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VectorQuadraticFunction{T},
    set::MOI.Nonpositives,
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.VectorAffineFunction{T}(func.affine_terms, func.constants),
        set,
    )
    if !_quadratic_vexity(func, 1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
    set::MOI.LessThan,
)
    coefficient = set.upper - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarQuadraticFunction{T},
    set::MOI.GreaterThan{T},
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.ScalarAffineFunction{T}(func.affine_terms, func.constant),
        set,
    )
    if !_quadratic_vexity(func, -1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VectorQuadraticFunction{T},
    set::MOI.Nonnegatives,
) where {T}
    _get_constraint_data(
        data,
        ref,
        MOI.VectorAffineFunction{T}(func.affine_terms, func.constants),
        set,
    )
    if !_quadratic_vexity(func, -1)
        push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
    set::MOI.GreaterThan,
)
    coefficient = set.lower - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarQuadraticFunction,
    set::Union{MOI.EqualTo,MOI.Interval},
)
    _get_constraint_data(
        data,
        ref,
        MOI.ScalarAffineFunction(func.affine_terms, func.constant),
        set,
    )
    push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VectorQuadraticFunction,
    set::MOI.Zeros,
)
    _get_constraint_data(
        data,
        ref,
        MOI.VectorAffineFunction(func.affine_terms, func.constants),
        set,
    )
    push!(data.nonconvex_rows, NonconvexQuadraticConstraint(ref))
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
    set::MOI.EqualTo,
)
    coefficient = set.value - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.ScalarAffineFunction,
    set::MOI.Interval,
)
    coefficient = set.upper - func.constant
    if !(iszero(coefficient))
        _update_range(data.rhs_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
        elseif abs(coefficient) > data.threshold_large
            push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
        end
    end
    coefficient = set.lower - func.constant
    if iszero(coefficient)
        return
    end
    _update_range(data.rhs_range, coefficient)
    if abs(coefficient) < data.threshold_small
        push!(data.rhs_small, SmallRHSCoefficient(ref, coefficient))
    elseif abs(coefficient) > data.threshold_large
        push!(data.rhs_large, LargeRHSCoefficient(ref, coefficient))
    end
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.LessThan,
)
    _get_variable_data(data, func, set.upper)
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.GreaterThan,
)
    _get_variable_data(data, func, set.lower)
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.EqualTo,
)
    _get_variable_data(data, func, set.value)
    return
end

function _get_constraint_data(
    data,
    ref,
    func::MOI.VariableIndex,
    set::MOI.Interval,
)
    _get_variable_data(data, func, set.lower)
    _get_variable_data(data, func, set.upper)
    return
end

function _get_constraint_data(data, ref, func::MOI.VariableIndex, set)
    return
end

function _get_variable_data(data, variable, coefficient::Number)
    if !(iszero(coefficient))
        _update_range(data.bounds_range, coefficient)
        if abs(coefficient) < data.threshold_small
            push!(
                data.bounds_small,
                SmallBoundCoefficient(variable, coefficient),
            )
        elseif abs(coefficient) > data.threshold_large
            push!(
                data.bounds_large,
                LargeBoundCoefficient(variable, coefficient),
            )
        end
    end
    return
end

function _get_constraint_data(data, ref, func::MOI.VectorOfVariables, set)
    return
end
