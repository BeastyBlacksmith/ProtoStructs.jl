using ProtoStructs, Test

@proto struct TestMe{T}
    A::Int
    B
    C::T
end
test_me = @test_nowarn TestMe(1, "2", complex(1))
test_me_kw = @test_nowarn TestMe(A=1, B="2", C=complex(1))

@testset "Construction" begin
    @test TestMe((A=1,)) isa TestMe
    @test TestMe(A=1) == TestMe((A=1,))
end # testset

@testset "Access" begin
    @test test_me.A == 1
    @test test_me.B == "2"
    @test test_me.C == complex(1)
end # testset

@testset "Properties" begin
    @test propertynames( test_me ) == (:A, :B, :C)
end # testset

@proto struct TestMe{T}
    A::Int
    B
    C::T
    D::T
end

test_me = @test_nowarn TestMe(1, "2", complex(1))
test_me_kw = @test_nowarn TestMe(A=1, B="2", C=complex(1))

@testset "Redefinition" begin
    @test TestMe((A=1,)) isa TestMe
    @test TestMe(A=1) == TestMe((A=1,))
end # testset
