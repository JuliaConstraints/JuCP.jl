# AllDifferent.
# Nice syntax:    @constraint(m, alldifferent(x, y, z))
# Default syntax: @constraint(m, [x, y, z] in AllDifferent(3))
function JuMP.parse_one_operator_constraint(_error::Function, ::Bool, ::Val{:alldifferent}, arg...)
  # All variables are explicit in the call. For instance: @constraint(m, alldifferent(x, y)).
  if length(arg) > 1 && typeof(arg) <: Tuple && all(typeof(arg).parameters .== Symbol)
    set = CP.AllDifferent(length(arg))
    func = Expr(:vect, arg...)

    variable, parse_code = JuMP._MA.rewrite(func)
    build_call = JuMP._build_call(_error, false, variable, set)
    return parse_code, build_call
  end

  # The number of variables is not statically known, generate some code to get it.
  # All the generated code will be run in JuMP's scope, hence the set_ variable.
  set_ = CP.AllDifferent
  variable, parse_code = JuMP._MA.rewrite(arg[1])
  build_call = :(build_constraint($_error, $variable, ($set_)(length($variable))))
  return parse_code, build_call
end

# Domain.
# Nice syntax:    @constraint(m, x in [1, 2, 3]), like Membership
# Default syntax: @constraint(m, x in Domain(Set(1, 2, 3)))
function JuMP.build_constraint(_error::Function, func::AbstractJuMPScalar, values::Vector{T}) where {T <: Real}
  return ScalarConstraint(func, CP.Domain(Set(values)))
end

# Membership.
# Nice syntax:    @constraint(m, x in [y, z]), like Domain
# Default syntax: @constraint(m, [x, y, z] in Membership(3))
# Also works with mixed variables and constants: @constraint(m, x in [y, z, 1])
function JuMP.build_constraint(_error::Function, func::AbstractJuMPScalar, values::Vector{<:JuMP.AbstractJuMPScalar})
  return VectorConstraint(vcat([func], values), CP.Membership(length(values)))
end

# DifferentFrom.
# Nice syntax:    @constraint(m, x != y)
# Default syntax: @constraint(m, x - y in DifferentFrom(0.0))
JuMP.sense_to_set(_error::Function, ::Val{:(!=)}) = CP.DifferentFrom(0.0)

# Strictly.
JuMP.sense_to_set(_error::Function, ::Val{:(<)}) = CP.Strictly(MOI.LessThan(0.0))
JuMP.sense_to_set(_error::Function, ::Val{:(>)}) = CP.Strictly(MOI.GreaterThan(0.0))

# Element.
# Nicer syntax:   @constraint(m, y == array[x]) TODO
# Nicer syntax:   @constraint(m, y == element(array, x)) TODO
# Nice syntax:    @constraint(m, element(y, array, x))
# Default syntax: @constraint(m, [y, x] in Element(array, 2))
function JuMP.parse_one_operator_constraint(_error::Function, ::Bool, ::Val{:element}, arg...)
  if length(arg) != 3
    error("element() constraints must have three operands: the destination, the array, the index.")
  end

  variable, parse_code_variable = JuMP._MA.rewrite(arg[1])
  array = esc(arg[2])
  index, parse_code_index = JuMP._MA.rewrite(arg[3])
  parse_code = :($parse_code_variable; $parse_code_index)

  # TODO: Likely limitation, when passing a variable as array, modifying the array in the user code will not change the array in the constraint. Problematic or not?
  set_ = CP.Element
  build_call = :(build_constraint($_error, [$variable, $index], ($set_)($array, 2)))
  return false, parse_code, build_call
end
#
# function JuMP.rewrite_call_expression(_error::Function, head::Val{:element}, array, index)
#   # Create the variable to replace the expression.
#   m = gensym()
#   vi = gensym()
#   var = gensym()
#
#   parse_code_var = quote
#     $m = owner_model($(esc(index)))
#     $vi = VariableInfo(false, NaN, false, NaN, false, NaN, false, NaN, false, false)
#     $var = add_variable($m, build_variable($_error, $vi), "")
#   end
#
#   # Add the constraint for this new variable.
#   set_ = CP.Element
#   idx, parse_code_index = JuMP._MA.rewrite(index)
#   build_code_con = quote
#     add_constraint($m, build_constraint($_error, [$var, $idx], ($set_)($(esc(array)), 2)))
#   end
#
#   return :($parse_code_var; $parse_code_index), build_code_con, var
# end

# Sort.
# Nicer syntax:   @constraint(m, [y1, y2] == sort([x1, x2])) TODO
# Nice syntax:    @constraint(m, sort([x1, x2], [y1, y2]))
# Default syntax: @constraint(m, [x1, x2, y1, y2] in Sort(2))
function JuMP.parse_one_operator_constraint(_error::Function, ::Bool, ::Val{:sort}, arg...)
  if length(arg) != 2
    error("sort() constraints must have two operands: the array to sort, its elements in sorted order.")
  end

  # Parse the inputs.
  original, parse_code_original = JuMP._MA.rewrite(arg[1])
  destination, parse_code_destination = JuMP._MA.rewrite(arg[2])
  parse_code = :($parse_code_original; $parse_code_destination)

  # Check whether the arrays have all the same size.
  check_code = quote
    if length($original) != length($destination)
      error("Expected to have arrays of the same size, but the array to sort has size $(length($original)) " *
            "and the output sorted array has size $(length($destination)).")
    end
  end
  parse_code = :($parse_code; $check_code)

  # Generate the constraint.
  set_ = CP.Sort
  build_call = :(build_constraint($_error, vcat($original, $destination), ($set_)(length($original))))
  return parse_code, build_call
end

# SortPermutation.
# Nicer syntax:   @constraint(m, [y1, y2] == sortpermutation([x1, x2])) TODO
# Nice syntax:    @constraint(m, sortpermutation([x1, x2], [z1, z2]))
# Nice syntax:    @constraint(m, sortpermutation([x1, x2], [y1, y2], [z1, z2]))
# Default syntax: @constraint(m, [x1, x2, y1, y2, z1, z2] in SortPermutation(2))
# I.e. the sorted values are not available with the nicer syntax, and should be retrieved through Element.
function JuMP.parse_one_operator_constraint(_error::Function, ::Bool, ::Val{:sortpermutation}, arg...)
  if length(arg) != 2 && length(arg) != 3
    error("sortpermutation() constraints must have two or three operands: the array to sort, optionally its elements in sorted order, the sorting permutation.")
  end

  # Parse the inputs.
  original, parse_code_original = JuMP._MA.rewrite(arg[1])
  array1, parse_code_array1 = JuMP._MA.rewrite(arg[2])
  parse_code = :($parse_code_original; $parse_code_array1)
  if length(arg) == 3
    array2, parse_code_array2 = JuMP._MA.rewrite(arg[3])
    parse_code = :($parse_code; $parse_code_array2)
  else
    array2 = array1
    array1 = gensym()
    create_array1 = quote
      $array1 = VariableRef[]
      for i in 1:length($original)
        push!($array1,
              add_variable(owner_model(first($original)),
                           build_variable($_error,
                                          VariableInfo(false, NaN, false, NaN, false, NaN, false, NaN, false, false)),
                           ""))
      end
    end
    parse_code = :($parse_code; $create_array1)
  end

  # Check whether the arrays have all the same size.
  if length(arg) == 2
    check_code = quote
      if length($original) != length($array1)
        error("Expected to have arrays of the same size, but the array to sort has size $(length($original)) " *
              "and the output array for the permutation has size $(length($array1)).")
      end
    end
  else
    check_code = quote
      if length($original) != length($array1)
        error("Expected to have arrays of the same size, but the array to sort has size $(length($original)) " *
              "and the output sorted array has size $(length($array1)).")
      end
      if length($original) != length($array2)
        error("Expected to have arrays of the same size, but the array to sort has size $(length($original)) " *
              "and the output array for the permutation has size $(length($array2)).")
      end
    end
  end
  parse_code = :($parse_code; $check_code)

  # Generate the constraint.
  set_ = CP.SortPermutation
  build_call = :(build_constraint($_error, vcat($original, $array1, $array2), ($set_)(length($original))))
  return parse_code, build_call
end

# BinPacking.
# Nicer syntax:   @constraint(m, [load1, load2, assigned1, assigned2] == binpacking([size1, size2])) TODO
# Nice syntax:    @constraint(m, binpacking([size1, size2], [load1, load2], [assigned1, assigned2]))
# Default syntax: @constraint(m, [load1, load2, assigned1, assigned2, size1, size2] in BinPacking(2, 2))

# CapacitatedBinPacking.
# Nicer syntax:   @constraint(m, [load1, load2, assigned1, assigned2] == binpacking([size1, size2], [capa1, capa2])) TODO
# Nice syntax:    @constraint(m, binpacking([size1, size2], [load1, load2], [assigned1, assigned2], [capa1, capa2]))
# Default syntax: @constraint(m, [load1, load2, assigned1, assigned2, size1, size2, capa1, capa2] in CapacitatedBinPacking(2, 2))
function JuMP.parse_one_operator_constraint(_error::Function, ::Bool, ::Val{:binpacking}, arg...)
  if length(arg) != 3 && length(arg) != 4
    error("binpacking() constraints must have three or four operands: the bin loads, the assignment for each item, the item sizes, and optionnally the bin capacities.")
  end

  # Parse the inputs.
  load, parse_code_load = JuMP._MA.rewrite(arg[1])
  assign, parse_code_assign = JuMP._MA.rewrite(arg[2])
  size, parse_code_size = JuMP._MA.rewrite(arg[3])
  parse_code = :($parse_code_load; $parse_code_assign; $parse_code_size)

  if length(arg) == 4
    capa, parse_code_capa = JuMP._MA.rewrite(arg[4])
    parse_code = :($parse_code; $parse_code_capa)
  end

  # Check whether the arrays have all the same size.
  check_code = quote
    if length($assign) != length($size)
      error("Expected to have arrays of the same size, but the item-assignment array has size $(length($assign)) " *
            "and the item-size array has size $(length($size)).")
    end
  end
  parse_code = :($parse_code; $check_code)

  if length(arg) == 4
    check_code = quote
      if length($load) != length($capa)
        error("Expected to have arrays of the same size, but the bin-load array has size $(length($load)) " *
              "and the bin-capacity array has size $(length($capa)).")
      end
    end
    parse_code = :($parse_code; $check_code)
  end

  # Generate the constraint.
  if length(arg) == 3
    set_ = CP.BinPacking
    build_call = :(build_constraint($_error, vcat($load, $assign, $size), ($set_)(length($load), length($assign))))
  elseif length(arg) == 4
    set_ = CP.CapacitatedBinPacking
    build_call = :(build_constraint($_error, vcat($load, $assign, $size, $capa), ($set_)(length($load), length($assign))))
  end
  return parse_code, build_call
end

# Count.
# Nice syntax:    @constraint(m, y == count(1.0, x1, x2, x3)) TODO
# Default syntax: @constraint(m, [y, x1, x2, x3] in Count(1.0, 3))

# CountDistinct.
# Nice syntax:    @constraint(m, y == countdistinct(x1, x2, x3)) TODO
# Default syntax: @constraint(m, [y, x1, x2, x3] in CountDistinct(3))

# ReificationSet.

function _build_reified_constraint(
  _error::Function, variable::AbstractVariableRef,
  constraint::ScalarConstraint, ::Type{MOI.IndicatorSet{A}}) where A
  # TODO.
  set = MOI.IndicatorSet{A}(moi_set(constraint))
  return VectorConstraint([variable, jump_function(constraint)], set)
end

function JuMP.parse_constraint(_error::Function, ::Val{:(:=)}, arg...)
  if length(arg) != 2
    error("A reification constraint must have the following form: variable := { constraint }")
  end
  lhs, rhs = arg

  # Parse the left-hand variable.
  if typeof(lhs) != Symbol
    error("A reification constraint must have the following form: variable := { constraint }. The left-hand expression is not a single variable, but rather `$(arg[1])`.")
  end

  # Parse the right-hand constraint.
  if !Meta.isexpr(rhs, :braces) || length(rhs.args) != 1
      _error("Invalid right-hand side `$(rhs)` of reification constraint. Expected constraint surrounded by `{` and `}`.")
  end

  rhs_con = rhs.args[1]
  rhs_vectorized, rhs_parse_code, rhs_build_call = parse_constraint(_error, Val(rhs_con.head), rhs_con.args...)
  if rhs_vectorized
      _error("Reified constraint cannot be vectorized.")
  end

  # Build the reified constraint.
  set_ = CP.ReificationSet
  reified_build_call = quote
    return VectorConstraint(vcat([$(esc(lhs))], jump_function($rhs_build_call)), ($set_)(moi_set($rhs_build_call)))
  end

  return false, rhs_parse_code, reified_build_call
end
