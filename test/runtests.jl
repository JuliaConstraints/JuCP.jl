using JuMP, JuCP, ConstraintProgrammingExtensions

using Test

const CP = ConstraintProgrammingExtensions

@testset "JuCP" begin
    @testset "AllDifferent" begin
        m = Model()
        @variable(m, x)
        @variable(m, y)
        @variable(m, z)

        @constraint(m, cref, alldifferent(x, y, z))

        c = JuMP.constraint_object(cref)
        @test c.func == [x, y, z]
        @test c.set == CP.AllDifferent(3)
    end
end
