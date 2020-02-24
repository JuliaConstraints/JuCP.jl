# AllDifferent.
# Nice syntax:    @constraint(m, alldifferent(x, y, z))
# Default syntax: @constraint(m, [x, y, z] in AllDifferent(3))
function JuMP.parse_call_constraint(errorf::Function, ::Val{:alldifferent}, F...)
  # All variables are explicit in the call. For instance: @constraint(m, alldifferent(x, y)).
  if length(F) > 1 && typeof(F) <: Tuple && all(p == Symbol for p in typeof(F).parameters)
    set = CP.AllDifferent(length(F))
    func = Expr(:vect, F...)

    variable, parse_code = JuMP._MA.rewrite(func)
    build_call = JuMP._build_call(errorf, false, variable, set)
    return false, parse_code, build_call
  end

  # The number of variables is not statically known, generate some code to get it.
  # All the generated code will be run in JuMP's scope, hence the set_ variable.
  set_ = CP.AllDifferent
  variable, parse_code = JuMP._MA.rewrite(F[1])
  build_call = :(build_constraint($errorf, $variable, ($set_)(length($variable))))
  return false, parse_code, build_call
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
# Nice syntax:    @constraint(m, element(y, array, x))
# Default syntax: @constraint(m, [y, x] in Element(array, 2))
function JuMP.parse_call_constraint(errorf::Function, ::Val{:element}, F...)
  if length(F) != 3
    error("element() constraints must have three operands: the destination, the array, the index.")
  end

  variable, parse_code_variable = JuMP._MA.rewrite(F[1])
  array = esc(F[2])
  index, parse_code_index = JuMP._MA.rewrite(F[3])
  parse_code = :($parse_code_variable; $parse_code_index)

  # TODO: Likely limitation, when passing a variable as array, modifying the array in the user code will not change the array in the constraint. Problematic or not?
  set_ = CP.Element
  build_call = :(build_constraint($errorf, [$variable, $index], ($set_)($array, 2)))
  return false, parse_code, build_call
end

# Sort.
# Nicer syntax:   @constraint(m, [y1, y2] == sort([x1, x2])) TODO
# Nice syntax:    @constraint(m, sort([x1, x2], [y1, y2]))
# Default syntax: @constraint(m, [x1, x2, y1, y2] in Sort(2))
function JuMP.parse_call_constraint(errorf::Function, ::Val{:sort}, F...)
  if length(F) != 2
    error("sort() constraints must have two operands: the array to sort, its elements in sorted order.")
  end

  # Parse the inputs.
  original, parse_code_original = JuMP._MA.rewrite(F[1])
  destination, parse_code_destination = JuMP._MA.rewrite(F[2])
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
  build_call = :(build_constraint($errorf, vcat($original, $destination), ($set_)(length($original))))
  return false, parse_code, build_call
end

# SortPermutation.
# Nicer syntax:   @constraint(m, [y1, y2] == sortpermutation([x1, x2])) TODO
# Nice syntax:    @constraint(m, sortpermutation([x1, x2], [z1, z2]))
# Nice syntax:    @constraint(m, sortpermutation([x1, x2], [y1, y2], [z1, z2]))
# Default syntax: @constraint(m, [x1, x2, y1, y2, z1, z2] in SortPermutation(2))
# I.e. the sorted values are not available with the nicer syntax, and should be retrieved through Element.
function JuMP.parse_call_constraint(errorf::Function, ::Val{:sortpermutation}, F...)
  if length(F) != 2 && length(F) != 3
    error("sortpermutation() constraints must have two or three operands: the array to sort, optionally its elements in sorted order, the sorting permutation.")
  end

  # Parse the inputs.
  original, parse_code_original = JuMP._MA.rewrite(F[1])
  array1, parse_code_array1 = JuMP._MA.rewrite(F[2])
  parse_code = :($parse_code_original; $parse_code_array1)
  if length(F) == 3
    array2, parse_code_array2 = JuMP._MA.rewrite(F[3])
    parse_code = :($parse_code; $parse_code_array2)
  else
    array2 = array1
    array1 = gensym()
    create_array1 = quote
      $array1 = VariableRef[]
      for i in 1:length($original)
        push!($array1,
              add_variable(owner_model(first($original)),
                           build_variable($errorf,
                                          VariableInfo(false, NaN, false, NaN, false, NaN, false, NaN, false, false)),
                           ""))
      end
    end
    parse_code = :($parse_code; $create_array1)
  end

  # Check whether the arrays have all the same size.
  if length(F) == 2
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
  build_call = :(build_constraint($errorf, vcat($original, $array1, $array2), ($set_)(length($original))))
  return false, parse_code, build_call
end

# BinPacking.
# Nicer syntax:   @constraint(m, [load1, load2, assigned1, assigned2] == binpacking([size1, size2])) TODO
# Nice syntax:    @constraint(m, binpacking([size1, size2], [load1, load2], [assigned1, assigned2]))
# Default syntax: @constraint(m, [load1, load2, assigned1, assigned2, size1, size2] in BinPacking(2, 2))

# CapacitatedBinPacking.
# Nicer syntax:   @constraint(m, [load1, load2, assigned1, assigned2] == binpacking([size1, size2], [capa1, capa2])) TODO
# Nice syntax:    @constraint(m, binpacking([size1, size2], [load1, load2], [assigned1, assigned2], [capa1, capa2]))
# Default syntax: @constraint(m, [load1, load2, assigned1, assigned2, size1, size2, capa1, capa2] in CapacitatedBinPacking(2, 2))
function JuMP.parse_call_constraint(errorf::Function, ::Val{:binpacking}, F...)
  if length(F) != 3 && length(F) != 4
    error("binpacking() constraints must have three or four operands: the bin loads, the assignment for each item, the item sizes, and optionnally the bin capacities.")
  end

  # Parse the inputs.
  load, parse_code_load = JuMP._MA.rewrite(F[1])
  assign, parse_code_assign = JuMP._MA.rewrite(F[2])
  size, parse_code_size = JuMP._MA.rewrite(F[3])
  parse_code = :($parse_code_load; $parse_code_assign; $parse_code_size)

  if length(F) == 4
    capa, parse_code_capa = JuMP._MA.rewrite(F[4])
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

  if length(F) == 4
    check_code = quote
      if length($load) != length($capa)
        error("Expected to have arrays of the same size, but the bin-load array has size $(length($load)) " *
              "and the bin-capacity array has size $(length($capa)).")
      end
    end
    parse_code = :($parse_code; $check_code)
  end

  # Generate the constraint.
  if length(F) == 3
    set_ = CP.BinPacking
    build_call = :(build_constraint($errorf, vcat($load, $assign, $size), ($set_)(length($load), length($assign))))
  elseif length(F) == 4
    set_ = CP.CapacitatedBinPacking
    build_call = :(build_constraint($errorf, vcat($load, $assign, $size, $capa), ($set_)(length($load), length($assign))))
  end
  return false, parse_code, build_call
end

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
