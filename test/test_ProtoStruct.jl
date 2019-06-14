using ProtoStructs, Test

@proto TestMe

@testset "Construction" begin
    @test TestMe((A=1,)) isa TestMe
    @test_broken TestMe(A=1, B="2", C=complex(1))
end # testset
