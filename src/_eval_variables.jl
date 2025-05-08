# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _eval_variables end

function _eval_variables(value_fn::Function, t::MOI.ScalarAffineTerm)
    return t.coefficient * value_fn(t.variable)
end

function _eval_variables(value_fn::Function, t::MOI.ScalarQuadraticTerm)
    out = t.coefficient * value_fn(t.variable_1) * value_fn(t.variable_2)
    return t.variable_1 == t.variable_2 ? out / 2 : out
end

_eval_variables(value_fn::Function, f::MOI.VariableIndex) = value_fn(f)

function _eval_variables(
    value_fn::Function,
    f::MOI.ScalarAffineFunction{T},
) where {T}
    # TODO: this conversion exists in JuMP, but not in MOI
    S = Base.promote_op(value_fn, MOI.VariableIndex)
    U = Base.promote_op(*, T, S)
    out = convert(U, f.constant)
    for t in f.terms
        out += _eval_variables(value_fn, t)
    end
    return out
end
