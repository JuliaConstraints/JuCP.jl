module JuCP

using JuMP
using ConstraintProgrammingExtensions

const CP = ConstraintProgrammingExtensions

# AllDifferent.
# Nice syntax:    @constraint(m, alldifferent(x, y, z))
# Default syntax: @constraint(m, [x, y, z] in AllDifferent(3))
JuMP.is_one_argument_constraint(::Val{:alldifferent}) = true

function JuMP.parse_one_operator_constraint(errorf::Function, vectorized::Bool,
                                            ::Val{:alldifferent}, F)
  return JuMP.parse_one_operator_constraint(errorf, vectorized, Val(:∈), F, CP.AllDifferent(length(F.args)))
end

# Domain. The base implementation of build_constraint is enough.
# Default syntax: @constraint(m, x in Domain(Set(1, 2, 3)))
# TODO: find something closer to @constraint(m, x in [1, 2]), like Membership
# function build_constraint(_error::Function, func::AbstractJuMPScalar,
#                           set::Domain{T}) where T
#     return ScalarConstraint(func, set)
# end

# Membership. TODO: find a nice syntax.
# Default syntax: @constraint(m, [x, y, z] in Membership(3))
# TODO: find something closer to @constraint(m, x in [y, z]), like Domain
# function build_constraint(_error::Function, func::AbstractJuMPScalar,
#                           set::Membership) where T
#     return ScalarConstraint(func, set)
# end

# DifferentFrom.
# Nice syntax:    @constraint(m, x != y)
# Default syntax: @constraint(m, x - y in DifferentFrom(0.0))
JuMP.sense_to_set(_error::Function, ::Val{:(!=)}) = CP.DifferentFrom(0.0)

# Count.
# Nice syntax:    @constraint(m, y == count(1.0, x1, x2, x3)) TODO
# Default syntax: @constraint(m, [y, x1, x2, x3] in Count(1.0, 3))

# CountDistinct.
# Nice syntax:    @constraint(m, y == countdistinct(x1, x2, x3)) TODO
# Default syntax: @constraint(m, [y, x1, x2, x3] in CountDistinct(3))

# Strictly.
JuMP.sense_to_set(_error::Function, ::Val{:(<)}) = CP.Strictly(MOI.LessThan(0.0))
JuMP.sense_to_set(_error::Function, ::Val{:(>)}) = CP.Strictly(MOI.GreaterThan(0.0))

# ReificationSet.

function _build_reified_constraint(
  _error::Function, variable::AbstractVariableRef,
  constraint::ScalarConstraint, ::Type{MOI.IndicatorSet{A}}) where A
  # TODO.
  set = MOI.IndicatorSet{A}(moi_set(constraint))
  return VectorConstraint([variable, jump_function(constraint)], set)
end

function JuMP.parse_one_operator_constraint(_error::Function, vectorized::Bool, ::Val{:(:=)}, lhs, rhs)
  # Inspired by indicator constraints.
  variable, S = _indicator_variable_set(_error, lhs)
  if !isexpr(rhs, :braces) || length(rhs.args) != 1
    _error("Invalid right-hand side `$(rhs)` of reified constraint. Expected constraint surrounded by `{` and `}`.")
  end
  rhs_con = rhs.args[1]
  rhs_vectorized, rhs_parsecode, rhs_buildcall = parse_constraint(_error, rhs_con.args...)
  if vectorized != rhs_vectorized
    _error("Inconsistent use of `.` in symbols to indicate vectorization.")
  end
  if vectorized
    buildcall = :(_build_reified_constraint.($_error, $(esc(variable)), $rhs_buildcall, $S))
  else
    buildcall = :(_build_reified_constraint($_error, $(esc(variable)), $rhs_buildcall, $S))
  end
  return rhs_parsecode, buildcall
end

end
