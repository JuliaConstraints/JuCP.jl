# JuCP.jl

[![Build Status](https://travis-ci.org/dourouc05/JuCP.jl.svg?branch=master)](https://travis-ci.org/dourouc05/JuCP.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/dourouc05/JuCP.jl?branch=master&svg=true)](https://ci.appveyor.com/project/dourouc05/JuCP-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/dourouc05/JuCP.jl/badge.svg?branch=master)](https://coveralls.io/r/dourouc05/JuCP.jl?branch=master)
[![codecov.io](http://codecov.io/github/dourouc05/JuCP.jl/coverage.svg?branch=master)](http://codecov.io/github/dourouc05/JuCP.jl?branch=master)

[JuMP](https://github.com/JuliaOpt/JuMP.jl) extensions for constraint programming.

These extensions rely on [ConstraintProgrammingExtensions](https://github.com/dourouc05/ConstraintProgrammingExtensions.jl), an extension for [MathOptInterface.jl](https://github.com/JuliaOpt/MathOptInterface.jl) providing several constraint-programming-oriented sets. There is already one solver providing some of these new sets: [CPLEXCP.jl](https://github.com/dourouc05/CPLEXCP.jl). 

For now, the new syntax can only be used with a patch applied on top of JuMP: [PR 2051](https://github.com/JuliaOpt/JuMP.jl/pull/2051).

## Design considerations

The goal of these series of packages is to provide access to constraint programming (CP) within Julia, considering that CP is barely unavailable in the ecosystem, the exception being [ConstraintSolver.jl](https://github.com/Wikunia/ConstraintSolver.jl). 

The CP environment is very different from the mathematical programming one (and it is not related to the lack of dual variables in CP solvers): the functionalities provided by the solvers do not easily match (some provide reified constraints, others equivalence constraints; some solvers provide specific expressions like `count(…)`, that may be then used in the objective function, others only support constraints like `x <= count(…)` or `x == count(…)`). You can express the same constraints with all solvers, but not always in the same way. Moreover, solvers tend not to provide callable libraries, unlike optimisation solvers: they provide higher-level APIs, usually in languages such as C++ or Java. This means that, for closed-source solvers, there is no access to the solver, only to a modelling layer (like CPLEX CP Optimizer). Similarly, many solvers are written in Java, and thus require an access to the JVM to be run. 

Due to these differences, the rationale behind the sets provided by [ConstraintProgrammingExtensions.jl](https://github.com/dourouc05/ConstraintProgrammingExtensions.jl) is to propose all new elements as constraints, and not functions. Solvers only supporting the constraint `count(…)` in the form `x == count(…)` directly match these definitions (for instance, Gecode). Others provide expressions for this constraints (like CPLEX CP Optimizer), but they can be used in constraints to match the same semantics. In other words, the goal is to provide a set of "flat" primitives that is supported by a large number of solvers. 

This is similar to what MiniZinc provides, except JuCP & co. work on the code level. [MiniZinc](https://www.minizinc.org/) is a common descriptive language for CP that is independently implemented by several solvers (like [Gecode](https://www.gecode.org/flatzinc.html), [JaCoP](https://github.com/radsz/jacop), [Choco](https://github.com/chocoteam/choco-solver)). Under the hood, MiniZinc transforms the input file in FlatZinc, a lower-level programming language (a kind of intermediate representation), which the solver then reads. This is similar to AMPL's NL format (in time, maybe [AmplNLWriter.jl](https://github.com/JuliaOpt/AmplNLWriter.jl) should be extended to handle CP extensions). [Savile Row](https://savilerow.cs.st-andrews.ac.uk/index.html) and [Conjure](https://github.com/conjure-cp/conjure) are similar in principle to MiniZinc, with the definition of a high-level language to describe the models (Essence), which is lowered by Conjure (Essence'); these two pieces of software also optimise the models, which is not, currently, a goal of JuCP & co.; again, communication is mostly made through files. On the other hand, JuCP & co. work by directly using the solvers' API, similarly to how other solvers work with JuMP/MOI. This approach has also been chosen by [ECLiPSe](http://eclipseclp.org/), for instance [to communicate with Gecode](https://github.com/antiguru/eclipse-clp/blob/af37a9ef7506f0eb05c4dba3b862241d1f5903e3/GecodeInterface/gfd.cpp).

## Next steps

In approximate order of importance: 

- Have [PR 2051](https://github.com/JuliaOpt/JuMP.jl/pull/2051) merged into JuMP to allow more syntax extensions. 
- Complete the solver wrapper [CPLEXCP.jl](https://github.com/dourouc05/CPLEXCP.jl). This means (again, in approximate order of importance): 
  - improving the test suite (see the next point)
  - adding the missing constraints
  - wrap the missing parts, especially tuning the search phase
  - study how to integrate it more with Julia, for instance [callbacks](https://developer.ibm.com/docloud/blog/2019/12/17/new-callback-functionality-in-cp-optimizer/)
- Decide what to do for testing the wrappers. Many tests in [MathOptInterface.jl](https://github.com/JuliaOpt/MathOptInterface.jl) do not apply, as the solvers are severely limited when it comes to continuous problems; also, they don't provide dual values. Changing variable types is often not possible, which implies that variables must be created with their constraint (`add_constrained_variable` instead of `add_variable` plus `add_constraint`). This probably calls for simplifying methods in [ConstraintProgrammingExtensions.jl](https://github.com/dourouc05/ConstraintProgrammingExtensions.jl) to only call the relevant tests in [MathOptInterface.jl](https://github.com/JuliaOpt/MathOptInterface.jl), plus providing a lot of new tests. 
- Determine how to expose more basic functionalities from solvers, like interval variables.
- Determine how to expose more advanced functionalities from solvers, like [custom propagators](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.10.0/ilog.odms.cpo.help/CP_Optimizer/Advanced_user_manual/topics/propagator_example.html), [custom constraints](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.10.0/ilog.odms.cpo.help/CP_Optimizer/Advanced_user_manual/topics/csts.html), [custom search techniques](https://www.ibm.com/support/knowledgecenter/SSSA5P_12.10.0/ilog.odms.cpo.help/CP_Optimizer/Advanced_user_manual/topics/goals_overview.html). [Search Combinators](https://arxiv.org/abs/1203.1095) can be a good start. 
- Write wrappers for more solvers. The major ones are: 
  - [Gecode](https://www.gecode.org/). In C++, models must inherit the Script class; have a look at their FlatZinc implementation, more precisely [ParserState](https://github.com/Gecode/gecode/blob/master/gecode/flatzinc/parser.hh#L184)? 
  - [JaCoP](https://github.com/radsz/jacop). Highly similar to CPLEX CP in Java, [no need to inherit from a given class](https://github.com/radsz/jacop/blob/develop/src/main/java/org/jacop/examples/fd/ExampleFD.java. 
  - [Choco](https://github.com/chocoteam/choco-solver), mostly the same. 
