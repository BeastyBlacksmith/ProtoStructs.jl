using ProtoStructs, Test

@proto struct TestMe{T, V <: Real}
    A::Int
    B
    C::T
    D::V
end
test_me = @test_nowarn TestMe(1, "2", complex(1), 5)
test_me_kw = @test_nowarn TestMe(A=1, B="2", C=complex(1), D=5)

@testset "Construction" begin
    @test test_me isa TestMe
    @test_throws UndefKeywordError TestMe(A=1)
end # testset

@testset "Access" begin
    @test test_me.A == 1
    @test test_me.B == "2"
    @test test_me.C == complex(1)
end # testset

@testset "Properties" begin
    @test propertynames( test_me ) == (:A, :B, :C, :D)
end # testset

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
end # testset

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
    @test_throws ErrorException tpm2 = TestParametricMutation{Int, Float64}(D = 1.2, E = "yepp")
    tpm2 = @test_nowarn TestParametricMutation{Nothing, Float64}(D = 1.2, E = "yepp")
    @test tpm2 isa TestParametricMutation
    @test tpm2 isa TestParametricMutation{Nothing, Float64}
    @test !(tpm2 isa TestParametricMutation{Nothing, Int})    
    @test_throws ErrorException tpm3 = TestParametricMutation{Int, Float64}(1, :no, nothing, 1.2, "yepp")
    tpm3 = @test_nowarn TestParametricMutation{Nothing, Float64}(1, :no, nothing, 1.2, "yepp")
    @test tpm3 isa TestParametricMutation
    @test tpm3 isa TestParametricMutation{Nothing, Float64}
    @test !(tpm3 isa TestParametricMutation{Nothing, Int})  
end
