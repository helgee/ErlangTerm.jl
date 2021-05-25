using ErlangTerm
using Test

@testset "ErlangTerm" begin
    @testset "Streams" begin
        buffer = IOBuffer()
        serialize(buffer, 1)
        @test take!(buffer) == UInt8[131, 97, 1]
    end
    @testset "Small Int" begin
        @test serialize(1) == UInt8[131, 97, 1]
        @test deserialize(serialize(1)) == 1
    end
    @testset "Large Int" begin
        @test serialize(256) == UInt8[131, 98, 0, 0, 1, 0]
        @test deserialize(serialize(256)) == 256
    end
    @testset "Small Big, Int64" begin
        i = Int(0x100000000)
        @test serialize(i) == UInt8[131, 110, 5, 0, 0, 0, 0, 0, 1]
        @test deserialize(serialize(i)) == i
        @test typeof(deserialize(serialize(i))) == Int64
        @test serialize(-i) == UInt8[131, 110, 5, 1, 0, 0, 0, 0, 1]
        @test deserialize(serialize(-i)) == -i
        @test typeof(deserialize(serialize(-i))) == Int64
    end
    @testset "Small Big, Int128" begin
        i = Int128(0x10000000000000000)
        @test serialize(i) == UInt8[131, 110, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        @test deserialize(serialize(i)) == i
        @test typeof(deserialize(serialize(i))) == Int128
        @test serialize(-i) == UInt8[131, 110, 9, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1]
        @test deserialize(serialize(-i)) == -i
        @test typeof(deserialize(serialize(-i))) == Int128
    end
    @testset "Small Big, BigInt" begin
        i = BigInt(16)^99     # 100 byte integer
        @test serialize(i)[1:5] == UInt8[131, 110, 50, 0, 0]
        @test deserialize(serialize(i)) == i
        @test typeof(deserialize(serialize(i))) == BigInt
        @test serialize(-i)[1:5] == UInt8[131, 110, 50, 1, 0]
        @test deserialize(serialize(-i)) == -i
        @test typeof(deserialize(serialize(-i))) == BigInt
    end
    @testset "Large Big, BigInt" begin
        i = BigInt(16)^599    # 600 byte integer
        @test serialize(i)[1:8] == UInt8[131, 111, 0, 0, 1, 44, 0, 0]
        @test deserialize(serialize(i)) == i
        @test typeof(deserialize(serialize(i))) == BigInt
        @test serialize(-i)[1:8] == UInt8[131, 111, 0, 0, 1, 44, 1, 0]
        @test deserialize(serialize(-i)) == -i
        @test typeof(deserialize(serialize(-i))) == BigInt
    end
    @testset "Float" begin
        @test serialize(1.0) == UInt8[131, 70, 63, 240, 0, 0, 0, 0, 0, 0]
        @test deserialize(serialize(1.0)) == 1.0
    end
    @testset "Atom" begin
        @test deserialize(UInt8[131, 100, 0, 4, 97, 116, 111, 109]) == :atom
    end
    @testset "String" begin
        @test deserialize(UInt8[131, 107, 0, 2, 1, 2]) == [1, 2]
    end
    @testset "Atom UTF-8" begin
        @test serialize(:μ) == UInt8[131, 119, 2, 206, 188]
        @test deserialize(serialize(:μ)) == :μ
    end
    @testset "Large Atom UTF-8" begin
        sym = Symbol(repeat("μ", 256))
        @test deserialize(serialize(sym)) == sym
    end
    @testset "Binary" begin
        @test serialize("erlang") == UInt8[131, 109, 0, 0, 0, 6, 101, 114, 108, 97, 110, 103]
        @test deserialize(serialize("erlang")) == "erlang"
        @test serialize("αω") == UInt8[131, 109, 0, 0, 0, 4, 206, 177, 207, 137]
        @test deserialize(serialize("αω")) == "αω"
    end
    @testset "List" begin
        @test serialize([]) == UInt8[131, 106]
        @test deserialize(serialize([])) == []

        list = [1024, :μ, "erlang"]
        @test serialize(list) == UInt8[131, 108, 0, 0, 0, 3, 98, 0, 0, 4, 0, 119, 2, 206, 188, 109, 0,
                                       0, 0, 6, 101, 114, 108, 97, 110, 103, 106]
        @test deserialize(serialize(list)) == list
    end
    @testset "Map" begin
        dict = Dict(:α => 1, :β => 2)
        exp1 = UInt8[131, 116, 0, 0, 0, 2, 119, 2, 206, 177, 97, 1, 119, 2, 206, 178, 97, 2]
        exp2 = UInt8[131, 116, 0, 0, 0, 2, 119, 2, 206, 178, 97, 2, 119, 2, 206, 177, 97, 1]
        act = serialize(dict)
        @test act == exp1 || act == exp2
        @test deserialize(serialize(dict)) == dict
    end
    @testset "Tuple" begin
        small_tuple = (1, 2, 3)
        @test serialize(small_tuple) == UInt8[131, 104, 3, 97, 1, 97, 2, 97, 3]
        @test deserialize(serialize(small_tuple)) == small_tuple

        large_tuple = (1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
                       23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42,
                       43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62,
                       63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82,
                       83, 84, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101,
                       102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117,
                       118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133,
                       134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149,
                       150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165,
                       166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181,
                       182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197,
                       198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
                       214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 229,
                       230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 245,
                       246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 256)
        large_result = UInt8[131, 105, 0, 0, 1, 0, 97, 1, 97, 2, 97, 3, 97, 4, 97, 5, 97, 6, 97, 7, 97,
                             8, 97, 9, 97, 10, 97, 11, 97, 12, 97, 13, 97, 14, 97, 15, 97, 16, 97, 17,
                             97, 18, 97, 19, 97, 20, 97, 21, 97, 22, 97, 23, 97, 24, 97, 25, 97, 26, 97,
                             27, 97, 28, 97, 29, 97, 30, 97, 31, 97, 32, 97, 33, 97, 34, 97, 35, 97, 36,
                             97, 37, 97, 38, 97, 39, 97, 40, 97, 41, 97, 42, 97, 43, 97, 44, 97, 45, 97,
                             46, 97, 47, 97, 48, 97, 49, 97, 50, 97, 51, 97, 52, 97, 53, 97, 54, 97, 55,
                             97, 56, 97, 57, 97, 58, 97, 59, 97, 60, 97, 61, 97, 62, 97, 63, 97, 64, 97,
                             65, 97, 66, 97, 67, 97, 68, 97, 69, 97, 70, 97, 71, 97, 72, 97, 73, 97, 74,
                             97, 75, 97, 76, 97, 77, 97, 78, 97, 79, 97, 80, 97, 81, 97, 82, 97, 83, 97,
                             84, 97, 85, 97, 86, 97, 87, 97, 88, 97, 89, 97, 90, 97, 91, 97, 92, 97, 93,
                             97, 94, 97, 95, 97, 96, 97, 97, 97, 98, 97, 99, 97, 100, 97, 101, 97, 102,
                             97, 103, 97, 104, 97, 105, 97, 106, 97, 107, 97, 108, 97, 109, 97, 110, 97,
                             111, 97, 112, 97, 113, 97, 114, 97, 115, 97, 116, 97, 117, 97, 118, 97, 119,
                             97, 120, 97, 121, 97, 122, 97, 123, 97, 124, 97, 125, 97, 126, 97, 127, 97,
                             128, 97, 129, 97, 130, 97, 131, 97, 132, 97, 133, 97, 134, 97, 135, 97, 136,
                             97, 137, 97, 138, 97, 139, 97, 140, 97, 141, 97, 142, 97, 143, 97, 144, 97,
                             145, 97, 146, 97, 147, 97, 148, 97, 149, 97, 150, 97, 151, 97, 152, 97, 153,
                             97, 154, 97, 155, 97, 156, 97, 157, 97, 158, 97, 159, 97, 160, 97, 161, 97,
                             162, 97, 163, 97, 164, 97, 165, 97, 166, 97, 167, 97, 168, 97, 169, 97, 170,
                             97, 171, 97, 172, 97, 173, 97, 174, 97, 175, 97, 176, 97, 177, 97, 178, 97,
                             179, 97, 180, 97, 181, 97, 182, 97, 183, 97, 184, 97, 185, 97, 186, 97, 187,
                             97, 188, 97, 189, 97, 190, 97, 191, 97, 192, 97, 193, 97, 194, 97, 195, 97,
                             196, 97, 197, 97, 198, 97, 199, 97, 200, 97, 201, 97, 202, 97, 203, 97, 204,
                             97, 205, 97, 206, 97, 207, 97, 208, 97, 209, 97, 210, 97, 211, 97, 212, 97,
                             213, 97, 214, 97, 215, 97, 216, 97, 217, 97, 218, 97, 219, 97, 220, 97, 221,
                             97, 222, 97, 223, 97, 224, 97, 225, 97, 226, 97, 227, 97, 228, 97, 229, 97,
                             230, 97, 231, 97, 232, 97, 233, 97, 234, 97, 235, 97, 236, 97, 237, 97, 238,
                             97, 239, 97, 240, 97, 241, 97, 242, 97, 243, 97, 244, 97, 245, 97, 246, 97,
                             247, 97, 248, 97, 249, 97, 250, 97, 251, 97, 252, 97, 253, 97, 254, 97, 255,
                             98, 0, 0, 1, 0]
        @test serialize(large_tuple) == large_result
        @test deserialize(serialize(large_tuple)) == large_tuple
    end
end
