using JuMP, JuCP

using Test

@testset "JuCP" begin
    @testset "AllDifferent" begin
        m = Model()
        @variable(m, x)
        @variable(m, y)
        @variable(m, z)

        @constraint(m, cref, alldifferent(x, y, z))

        c = JuMP.constraint_object(cref)
        @test c.func == [x, y, z]
        @test c.set == MOI.AllDifferent(3)
    end
end
