using ProtoStructs, Test

@proto TestMe
test_me = @test_nowarn TestMe(A=1, B="2", C=complex(1))

@testset "Construction" begin
    @test TestMe((A=1,)) isa TestMe
end # testset

@testset "Access" begin
    @test test_me.A == 1
    @test test_me.B == "2"
    @test test_me.C == complex(1)
end # testset
