# This does not implement necessary interface methods.
struct InvalidCodec <: TranscodingStreams.Codec end

@testset "Invalid Codec" begin
    @test_throws MethodError read(TranscodingStream(InvalidCodec(), IOBuffer()))
end
