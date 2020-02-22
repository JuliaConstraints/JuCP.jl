# AllDifferent.
# Nice syntax:    @constraint(m, alldifferent(x, y, z))
# Default syntax: @constraint(m, [x, y, z] in AllDifferent(3))
JuMP.is_one_argument_constraint(::Val{:alldifferent}) = true

function JuMP.parse_call_constraint(errorf::Function, ::Val{:alldifferent}, F...)
  set = CP.AllDifferent(length(F))
  func = Expr(:vect, F...)

  variable, parse_code = JuMP._MA.rewrite(func)
  build_call = JuMP._build_call(errorf, false, variable, set)
  return false, parse_code, build_call
end

# Domain.
# Default syntax: @constraint(m, x in Domain(Set(1, 2, 3)))
# TODO: find something closer to @constraint(m, x in [1, 2]), like Membership
# function build_constraint(_error::Function, func::AbstractJuMPScalar,
#                           set::Domain{T}) where T
#     return ScalarConstraint(func, set)
# end

# Membership.
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

# Element.
# Nicer syntax:   @constraint(m, y == array[x]) TODO
# Nice syntax:    @constraint(m, element(y, array, x)
# Default syntax: @constraint(m, [y, x] in Element(array, 2))
JuMP.is_one_argument_constraint(::Val{:element}) = true

# @eval JuMP begin # Not nice to do, but this ensures the function is available in the right context when called within the macro...
#   function _jucp_build_element_constraint(
#       errorf::Function,
#       ::AbstractArray{<:AbstractJuMPScalar},
#       ::AbstractArray{<:AbstractJuMPScalar},
#   )
#       errorf("second term must be an array of variables.")
#   end
# end
#
# function JuMP.parse_one_operator_constraint(errorf::Function, vectorized::Bool,
#                                             ::Val{:element}, F::Expr)
# println(F)
# println(F.head)
# println(F.args)
#
#   destination = F.args[1]
#   array = eval(F.args[2]) # TODO: does not work when the array is not 100% made explicit in the macro call.
#   index = F.args[3]
#   func = Expr(:vect, [destination, index])
#
#   return JuMP.parse_one_operator_constraint(errorf, vectorized, Val(:∈), F, CP.Element(array, 2))
# end

# Sort.
# Nice syntax:    @constraint(m, [y1, y2] == sort([x1, x2])) TODO
# Default syntax: @constraint(m, [x1, x2, y1, y2] in Sort(2))

# SortPermutation.
# Nice syntax:    @constraint(m, [y1, y2] == sortpermutation([x1, x2])) TODO
# Default syntax: @constraint(m, [x1, x2, z1, z2] in SortPermutation(2))
# I.e. the sorted values are not available, and should be retrieved through Element.

# BinPacking.
# Nice syntax:    @constraint(m, [load1, load2, assigned1, assigned2] == binpacking([size1, size2])) TODO
# Default syntax: @constraint(m, [load1, load2, assigned1, assigned2, size1, size2] in BinPacking(2, 2))

# CapacitatedBinPacking.
# Nice syntax:    @constraint(m, [load1, load2, assigned1, assigned2] == binpacking([size1, size2], [capa1, capa2])) TODO
# Default syntax: @constraint(m, [load1, load2, assigned1, assigned2, size1, size2, capa1, capa2] in CapacitatedBinPacking(2, 2))

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
