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

        @testset "Element" begin
            # # Exactly three arguments.
            # m = Model()
            # @variable(m, w)
            # @variable(m, x)
            # @variable(m, y)
            # @variable(m, z)
            #
            # # Looks like a bug in Julia: exceptions are not caught when directly using the macro in the test.
            # @test_throws ErrorException @constraint(m, element(x, y))
            # @test_throws ErrorException @constraint(m, element(w, x, y, z))

            # Constant array.
            m = Model()
            @variable(m, x)
            @variable(m, y)

            @constraint(m, cref, element(x, [1, 2, 3], y))

            c = JuMP.constraint_object(cref)
            @test c.func == [x, y]
            @test c.set == CP.Element([1, 2, 3], 2)

            # Variable array.
            m = Model()
            @variable(m, x)
            @variable(m, y)

            array = [1, 2, 3]
            @constraint(m, cref, element(x, array, y))

            c = JuMP.constraint_object(cref)
            @test c.func == [x, y]
            @test c.set == CP.Element(array, 2)

            # TODO: Decide if this is wanted or not.
            push!(array, 4)
            @test c.set == CP.Element(array, 2)
        end

        @testset "Sort" begin
            # Exactly two arguments.
            # TODO: same as above, probably...

            # All arrays must have the same size.
            # TODO: same as above, probably...

            # Variable array.
            m = Model()
            @variable(m, x[1:10])
            @variable(m, y[1:10])

            @constraint(m, cref, sort(x, y))

            c = JuMP.constraint_object(cref)
            @test c.func == vcat(x, y)
            @test c.set == CP.Sort(10)

            # Partly constant array.
            m = Model()
            @variable(m, x[1:10])
            @variable(m, y[1:9])

            @constraint(m, cref, sort(x, vcat(y, [1])))

            c = JuMP.constraint_object(cref)
            @test c.func == vcat(x, y, [1])
            @test c.set == CP.Sort(10)
        end

        @testset "SortPermutation" begin
            # Either two or three arguments.
            # TODO: same as above, probably...

            # All arrays must have the same size.
            # TODO: same as above, probably...

            # Two arguments: get rid of the sorted array.
            m = Model()
            @variable(m, x[1:10])
            @variable(m, y[1:10])

            @constraint(m, cref, sortpermutation(x, y))

            c = JuMP.constraint_object(cref)
            @test c.func[1:10] == x
            # Ten variables in the middle with no name.
            @test c.func[21:30] == y
            @test c.set == CP.SortPermutation(10)

            # Three arguments.
            m = Model()
            @variable(m, x[1:10])
            @variable(m, y[1:10])
            @variable(m, z[1:10])

            @constraint(m, cref, sortpermutation(x, y, z))

            c = JuMP.constraint_object(cref)
            @test c.func[1:10] == x
            @test c.func[11:20] == y
            @test c.func[21:30] == z
            @test c.set == CP.SortPermutation(10)
        end

        @testset "BinPacking and CapacitatedBinPacking" begin
            # Either three or four arguments.
            # TODO: same as above, probably...

            # Arrays must have the same size (items and bins).
            # TODO: same as above, probably...

            # Three arguments: ten items (fixed sizes), two bins.
            m = Model()
            @variable(m, x[1:2])
            @variable(m, y[1:10])

            @constraint(m, cref, binpacking(x, y, collect(1:10)))

            c = JuMP.constraint_object(cref)
            @test c.func[1:2] == convert(Vector{GenericAffExpr{Float64, VariableRef}}, x)
            @test c.func[3:12] == convert(Vector{GenericAffExpr{Float64, VariableRef}}, y)
            @test c.func[13:22] == convert(Vector{GenericAffExpr{Float64, VariableRef}}, collect(1:10))
            @test c.set == CP.BinPacking(2, 10)

            # Four arguments: ten items, two bins.
            m = Model()
            @variable(m, w[1:2])
            @variable(m, x[1:10])
            @variable(m, y[1:10])
            @variable(m, z[1:2])

            @constraint(m, cref, binpacking(w, x, y, z))

            c = JuMP.constraint_object(cref)
            @test c.func[1:2] == w
            @test c.func[3:12] == x
            @test c.func[13:22] == y
            @test c.func[23:24] == z
            @test c.set == CP.CapacitatedBinPacking(2, 10)
        end

        @testset "Reification" begin
            # Erroneous syntax.
            # TODO
            # @constraint(m, x := y)

            # One-variable constraint.
            m = Model()
            @variable(m, x)
            @variable(m, y)

            @constraint(m, cref, x := { y <= 5 })

            c = JuMP.constraint_object(cref)
            @test c.func == [x, y]
            @test c.set == CP.ReificationSet(MOI.LessThan(5.0))

            # Multiple-variable constraint.
            m = Model()
            @variable(m, x)
            @variable(m, y)
            @variable(m, z)

            @constraint(m, cref, z := { alldifferent(x, y) })

            c = JuMP.constraint_object(cref)
            @test c.func == [z, x, y]
            @test c.set == CP.ReificationSet(CP.AllDifferent(2))
        end
    end

    @testset "Bridges" begin
    end
end
