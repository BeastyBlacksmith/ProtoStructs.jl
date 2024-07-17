using ProtoStructs, Test

@proto struct SimpleTestMe
    A::Int
end

@proto struct TestMe{T, V <: Real}
    A::Int
    B
    C::T
    D::V
end
test_me = @test_nowarn TestMe(1, "2", complex(1), 5)
test_me_kw = @test_nowarn TestMe(A=1, B="2", C=complex(1), D=5)

@testset "Construction" begin
    @test SimpleTestMe(1) isa SimpleTestMe
    @test test_me isa TestMe
    @test_throws UndefKeywordError TestMe(A=1)
end

@testset "Printing" begin
    @test repr(test_me) == "TestMe{Complex{$Int}, $Int}(1, \"2\", 1 + 0im, 5)"
end

@testset "Access" begin
    @test test_me.A == 1
    @test test_me.B == "2"
    @test test_me.C == complex(1)
end

@testset "Properties" begin
    @test propertynames( test_me ) == (:A, :B, :C, :D)
end

@proto struct TestMe{T, V <: Real}
    A::Int
    B
    C::T
    D::V
    E::String
end
test_me2 = @test_nowarn TestMe(1, "2", complex(1), 5, "tadaa")
test_me_kw2 = @test_nowarn TestMe(A=1, B="2", C=complex(1), D=5, E="tadaa")

@testset "Redefinition" begin
    @test length(methods(TestMe)) == 2
end

@proto struct TestKw{T, V <: Real}
    A::Int = 1
    B = :no
    C::T = nothing
    D::V
    E::String
end

@testset "kwdef" begin
    tw = TestKw(D = 1.2, E = "yepp")
    @test tw isa TestKw
    @test tw.A == 1
    @test tw.B == :no
    @test tw.C === nothing
    @test tw.D == 1.2
    @test tw.E == "yepp"
end

@proto @kwdef struct TestMacroOutside
    A::Int = 1
end

@testset "@kwdef macro outside" begin
    tw = TestMacroOutside()
    @test tw isa TestMacroOutside
    @test tw.A == 1
end

@proto mutable struct TestMutation
    F::Int
    G::Float64
end

@testset "Mutation" begin
    tm = @test_nowarn TestMutation(4, 2.0)
    @test tm.F == 4 && tm.G == 2.0
    tm.F = 8
    @test tm.F == 8 && tm.G == 2.0
    @test_throws MethodError tm.F = "2"
    @test propertynames(tm) == (:F, :G)
end

abstract type AbstractMutation end

@proto mutable struct TestParametricMutation{T, V <: Real} <: AbstractMutation
    A::Int = 1
    B = :no
    C::T = nothing
    D::V
    E::String
end

@testset "Parametric Mutation" begin
    tpm = @test_nowarn TestParametricMutation(D = 1.2, E = "yepp")
    tpm.A = 2
    tpm.E = "nope"
    @test repr(tpm) == "TestParametricMutation{Nothing, Float64}(2, no, nothing, 1.2, \"nope\")"
    @test_throws ErrorException tpm.this = "is wrong"
    @test tpm isa TestParametricMutation
    @test tpm isa TestParametricMutation{Nothing, Float64}
    @test !(tpm isa TestParametricMutation{Nothing, Int})
    @test tpm.A == 2
    @test tpm.B == :no
    @test tpm.C === nothing
    @test tpm.D == 1.2
    @test tpm.E == "nope"
    @test TestParametricMutation <: AbstractMutation
    @test_throws MethodError tpm2 = TestParametricMutation{Int, Float64}(D = 1.2, E = "yepp")
    tpm2 = @test_nowarn TestParametricMutation{Nothing, Float64}(D = 1.2, E = "yepp")
    @test tpm2 isa TestParametricMutation
    @test tpm2 isa TestParametricMutation{Nothing, Float64}
    @test !(tpm2 isa TestParametricMutation{Nothing, Int})
    @test_throws MethodError tpm3 = TestParametricMutation{Int, Float64}(1, :no, nothing, 1.2, "yepp")
    tpm3 = @test_nowarn TestParametricMutation{Nothing, Float64}(1, :no, nothing, 1.2, "yepp")
    @test tpm3 isa TestParametricMutation
    @test tpm3 isa TestParametricMutation{Nothing, Float64}
    @test !(tpm3 isa TestParametricMutation{Nothing, Int})
end

@proto mutable struct TestParametricMutation{V <: Integer} <: AbstractMutation
    A::Int = 1
    B = :no
    C::Nothing = nothing
    D::V
    E::String
end

@testset "Parametric Redefinition" begin
    tpm = @test_nowarn TestParametricMutation(D = 1, E = "yepp")
    @test tpm isa TestParametricMutation{Int}
    @test tpm isa AbstractMutation
    @test_throws ErrorException @proto mutable struct TestParametricMutation{V<:Integer} <: Number
            A::Int = 1
            B = :no
            C::Nothing = nothing
            D::V
            E::String
        end
end

@static if VERSION >= v"1.8"
    @proto mutable struct WithConstFields{T}
        A::Int = 1
        const B = :no
        const C::T = 3
        D
        const E::Vector{Int} = Int[]
    end

    @testset "const fields" begin
        cf = @test_nowarn WithConstFields(D = 1.2)
        @test cf.A == 1
        @test cf.B == :no
        @test cf.C == 3
        @test_nowarn show(devnull, cf)
        cf.A = 5
        @test_throws ErrorException cf.B = :yes
        @test_throws ErrorException cf.C = 5
    end
end

@proto struct TestMethods end

@testset "Constuctor updating I" begin
    @test length(collect(methods(TestMethods))) == 1
end

@proto struct TestMethods
        a
        b
end

@testset "Constuctor updating II" begin
    @test length(collect(methods(TestMethods))) == 2
end

"""
This is a docstring.
"""
@proto struct DocTestMe
    A::Int
end

@testset "Docstring" begin
    @test string(@doc DocTestMe) == "This is a docstring.\n"
end

@proto @kwdef struct A{T}
    x::Array{T} = T[]
end

a = A{Int}()

@test a.x == []

@proto @kwdef struct A{T}
    x::Array{T} = T[]
    y::Int = 3
end

@test a.y == 3

@test A(; x = ["hello"]).x == ["hello"]

@proto @kwdef struct A{T}
    y::Int = 3
end

@test_throws ErrorException a.x
