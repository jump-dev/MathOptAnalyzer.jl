# Copyright (c) 2025: Joaquim Garcia, Oscar Dowson and contributors
#
# Use of this source code is governed by an MIT-style license that can be found
# in the LICENSE.md file or at https://opensource.org/licenses/MIT.

function _eval_variables end

function _eval_variables(value_fn::Function, t::MOI.ScalarAffineTerm)
    return t.coefficient * value_fn(t.variable)
end

_eval_variables(value_fn::Function, f::MOI.VariableIndex) = value_fn(f)

function _eval_variables(
    value_fn::Function,
    f::MOI.ScalarAffineFunction{T},
) where {T}
    # TODO: this conversion exists in JuMP, but not in MOI
    S = Base.promote_op(value_fn, MOI.VariableIndex)
    U = MOI.MA.promote_operation(*, T, S)
    out = convert(U, f.constant)
    for t in f.terms
        out += _eval_variables(value_fn, t)
    end
    return out
end
