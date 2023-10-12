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
    @test TestMe((A=1,)) isa TestMe
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
    @test length(methods(TestMe)) == 3
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

abstract type AbstractMutation end

@proto mutable struct TestMutation{T, V <: Real} <: AbstractMutation
    A::Int = 1
    B = :no
    C::T = nothing
    D::V
    E::String
end

@testset "Mutation" begin
    tm = @test_nowarn TestMutation(D = 1.2, E = "yepp")
    tm.A = 2
    tm.E = "nope"
    @test_throws ErrorException tm.this = "is wrong"
    @test tm isa TestMutation
    @test tm.A == 2
    @test tm.B == :no
    @test tm.C === nothing
    @test tm.D == 1.2
    @test tm.E == "nope"
    @test TestMutation <: AbstractMutation
end
