# JuCP.jl

[![Build Status](https://travis-ci.org/dourouc05/JuCP.jl.svg?branch=master)](https://travis-ci.org/dourouc05/JuCP.jl)
[![Build Status](https://ci.appveyor.com/api/projects/status/github/dourouc05/JuCP.jl?branch=master&svg=true)](https://ci.appveyor.com/project/dourouc05/JuCP-jl/branch/master)
[![Coverage Status](https://coveralls.io/repos/dourouc05/JuCP.jl/badge.svg?branch=master)](https://coveralls.io/r/dourouc05/JuCP.jl?branch=master)
[![codecov.io](http://codecov.io/github/dourouc05/JuCP.jl/coverage.svg?branch=master)](http://codecov.io/github/dourouc05/JuCP.jl?branch=master)

JuMP extensions for constraint programming.

These extensions rely on [ConstraintProgrammingExtensions](https://github.com/dourouc05/ConstraintProgrammingExtensions.jl), an extension for [MathOptInterface](https://github.com/JuliaOpt/MathOptInterface.jl) providing several constraint-programming-oriented sets. 

For now, the new syntax can only be used with a patch applied on top of JuMP: [PR 2051](https://github.com/JuliaOpt/JuMP.jl/pull/2051).
