using JuMP, JuCP, ConstraintProgrammingExtensions

using Test

const CP = ConstraintProgrammingExtensions

@testset "JuCP" begin
    @testset "Sets" begin
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

        @testset "DifferentFrom" begin
            m = Model()
            @variable(m, x)
            @variable(m, y)

            @constraint(m, cref, x != y)

            c = JuMP.constraint_object(cref)
            @test c.func == x - y
            @test c.set == CP.DifferentFrom(0.0)
        end

        @testset "Strictly(LessThan)" begin
            m = Model()
            @variable(m, x)
            @variable(m, y)

            @constraint(m, cref, x < y)

            c = JuMP.constraint_object(cref)
            @test c.func == x - y
            @test c.set == CP.Strictly(MOI.LessThan(0.0))
        end

        @testset "Strictly(GreaterThan)" begin
            m = Model()
            @variable(m, x)
            @variable(m, y)

            @constraint(m, cref, x > y)

            c = JuMP.constraint_object(cref)
            @test c.func == x - y
            @test c.set == CP.Strictly(MOI.GreaterThan(0.0))
        end
    end

    @testset "Bridges" begin
    end
end
