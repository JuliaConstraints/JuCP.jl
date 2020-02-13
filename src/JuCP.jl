module JuCP
  using JuMP
  using ConstraintProgrammingExtensions
  
  import JuMP: parse_one_operator_constraint, is_one_argument_constraint
  
  # AllDifferent.
  
  is_one_argument_constraint(::Val{:alldifferent}) = true
  
  function _build_alldifferent_constraint(
      errorf::Function,
      F::AbstractArray{<:AbstractJuMPScalar}
  )
      # TODO.
      return VectorConstraint(F, MOI.Complements(length(F)))
  end
  
  function parse_one_operator_constraint(
      errorf::Function,
      ::Bool,
      ::Val{:alldifferent},
      F
  )
      f, parse_code = _MA.rewrite(F)
      return parse_code, :(_build_alldifferent_constraint($errorf, $f))
  end
  
  # ReificationSet.
  
  function _build_reified_constraint(
      _error::Function, variable::AbstractVariableRef,
      constraint::ScalarConstraint, ::Type{MOI.IndicatorSet{A}}) where A
      # TODO.
      set = MOI.IndicatorSet{A}(moi_set(constraint))
      return VectorConstraint([variable, jump_function(constraint)], set)
  end
  
  function parse_one_operator_constraint(_error::Function, vectorized::Bool, ::Val{:(:=)}, lhs, rhs)
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