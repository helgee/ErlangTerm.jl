using Eterm
using Test

@testset "Eterm" begin
    @test serialize(1) == UInt8[131, 97, 1]
    @test deserialize(serialize(1)) == 1

    @test serialize(256) == UInt8[131, 98, 0, 0, 1, 0]
    @test deserialize(serialize(256)) == 256

    @test serialize(1.0) == UInt8[131, 70, 63, 240, 0, 0, 0, 0, 0, 0]
    @test deserialize(serialize(1.0)) == 1.0

    # We only support deserializing the deprecated ATOM_EXT type
    @test deserialize(serialize(:atom)) == :atom

    @test serialize(:μ) == UInt8[131, 119, 2, 206, 188]
    @test deserialize(serialize(:μ)) == :μ

    sym = Symbol(repeat("μ", 256))
    @test deserialize(serialize(sym)) == sym

    @test serialize("erlang") == UInt8[131, 109, 0, 0, 0, 6, 101, 114, 108, 97, 110, 103]
    @test deserialize(serialize("erlang")) == "erlang"

    @test serialize([]) == UInt8[131, 106]
    @test deserialize(serialize([])) == []

    list = [1024, :μ, "erlang"]
    @test serialize(list) == UInt8[131, 108, 0, 0, 0, 3, 98, 0, 0, 4, 0, 119, 2, 206, 188, 109, 0,
                                   0, 0, 6, 101, 114, 108, 97, 110, 103, 106]
    @test deserialize(serialize(list)) == list

    dict = Dict(:α => 1, :β => 2)
    @test serialize(dict) == UInt8[131, 116, 0, 0, 0, 2, 119, 2, 206, 177, 97, 1, 119, 2, 206, 178, 97, 2]
    @test deserialize(serialize(dict)) == dict

    complex = Dict(:α => Dict(:γ => list, :δ => list), :β => list)
    @test deserialize(serialize(complex)) == complex
end
