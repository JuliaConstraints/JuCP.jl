using JuMP, JuCP, ConstraintProgrammingExtensions

using Test

const CP = ConstraintProgrammingExtensions

@testset "JuCP" begin
    @testset "Sets" begin
        @testset "AllDifferent" begin
            # Different variables.
            m = Model()
            @variable(m, x)
            @variable(m, y)
            @variable(m, z)
            @constraint(m, cref, alldifferent(x, y, z))

            c = JuMP.constraint_object(cref)
            @test c.func == [x, y, z]
            @test c.set == CP.AllDifferent(3)

            # Whole array.
            m = Model()
            @variable(m, x[1:10])
            @constraint(m, cref, alldifferent(x))

            c = JuMP.constraint_object(cref)
            @test c.func == x
            @test c.set == CP.AllDifferent(10)

            # Portion of array (with end).
            m = Model()
            @variable(m, x[1:10])
            @constraint(m, cref, alldifferent(x[2:end]))

            c = JuMP.constraint_object(cref)
            @test c.func == x[2:end]
            @test c.set == CP.AllDifferent(9)
            # TODO: For now, impossible to infer the size of "x[^:end]..." in JuCP.

            # Portion of array.
            m = Model()
            @variable(m, x[1:10])
            @constraint(m, cref, alldifferent(x[2:9]))

            c = JuMP.constraint_object(cref)
            @test c.func == x[2:9]
            @test c.set == CP.AllDifferent(8) # Could do something about it to compute the dimension of the set, but probably not scalable for the other cases.
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

        @testset "Domain" begin
            m = Model()
            @variable(m, x)

            @constraint(m, cref, x in [1, 2, 3])

            c = JuMP.constraint_object(cref)
            @test c.func == x
            @test c.set == CP.Domain(Set([1, 2, 3]))
        end

        @testset "Membership" begin
            m = Model()
            @variable(m, w)
            @variable(m, x)
            @variable(m, y)
            @variable(m, z)

            @constraint(m, cref, w in [x, y, z])

            c = JuMP.constraint_object(cref)
            @test c.func == [w, x, y, z]
            @test c.set == CP.Membership(3)
        end

        @testset "Mixed Domain and Membership" begin
            m = Model()
            @variable(m, x)
            @variable(m, y)
            @variable(m, z)

            @constraint(m, cref, x in [y, z, 3])

            c = JuMP.constraint_object(cref)
            @test c.func == [x, y, z, 3]
            @test c.set == CP.Membership(3)
        end
    end

    @testset "Bridges" begin
    end
end
