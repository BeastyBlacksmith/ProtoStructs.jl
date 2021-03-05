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
    @test_throws MethodError TestMe(A=1)
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
