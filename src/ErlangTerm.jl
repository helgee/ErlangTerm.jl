module ErlangTerm

export serialize, deserialize

const NEW_FLOAT = UInt8(70)
const SMALL_INTEGER = UInt8(97)
const INTEGER = UInt8(98)
const ATOM = UInt8(100)
const SMALL_TUPLE = UInt8(104)
const LARGE_TUPLE = UInt8(105)
const NIL = UInt8(106)
const STRING = UInt8(107)
const LIST = UInt8(108)
const BINARY = UInt8(109)
const SMALL_BIG = UInt8(110)
const LARGE_BIG = UInt8(111)
const MAP = UInt8(116)
const ATOM_UTF8 = UInt8(118)
const SMALL_ATOM_UTF8 = UInt8(119)

const VERSION = UInt8(131)

"""
    deserialize(io::IO)
    deserialize(binary::Array{UInt8})

Deserialize a Julia value encoded in the
[Erlang external term format](http://erlang.org/doc/apps/erts/erl_ext_dist.html)
from a stream or an array of bytes.
"""
deserialize

"""
    serialize(io::IO, value)
    serialize(value)

Serialize a Julia value to the
[Erlang external term format](http://erlang.org/doc/apps/erts/erl_ext_dist.html).
"""
serialize

function deserialize(io::IO)
    version = read(io, UInt8)
    version != VERSION && throw(ArgumentError("Unknown external term format version: $(Int(version))."))

    tag = read(io, UInt8)
    deserialize(io, Val(tag))
end

deserialize(binary::Array{UInt8}) = deserialize(IOBuffer(binary))

function serialize(io::IO, data)
    write(io, VERSION)
    _serialize(io, data)
end

serialize(data) = take!(serialize(IOBuffer(), data))

function _serialize(io, val::Integer)
    if val > 0 && val <= typemax(UInt8)
        write(io, SMALL_INTEGER)
        write(io, UInt8(val))
    elseif abs(val) <= typemax(Int32)
        write(io, INTEGER)
        write(io, hton(Int32(val)))
    else
        arr = digits(UInt8, abs(val), base=0x100)
        n = length(arr)
        if n < 0x100
            write(io, SMALL_BIG)
            write(io, UInt8(n))
        else
            write(io, LARGE_BIG)
            write(io, hton(UInt32(n)))
        end
        write(io, UInt8(sign(val) == 1 ? 0 : 1))
        write(io, arr)
    end
    io
end

function deserialize(io, ::Val{SMALL_INTEGER})
    Int(read(io, UInt8))
end

function deserialize(io, ::Val{INTEGER})
    ntoh(read(io, Int32))
end

function _serialize(io, val::Float64)
    write(io, NEW_FLOAT)
    write(io, hton(val))
    io
end

function deserialize(io, ::Val{NEW_FLOAT})
    ntoh(read(io, Float64))
end

function _serialize(io, val::Symbol)
    str = Array{UInt8}(string(val))
    n = length(str)
    if n > typemax(UInt16)
        throw(ArgumentError("Cannot serialize symbols with more than $(typemax(UInt16)) characters."))
    elseif n > typemax(UInt8)
        write(io, ATOM_UTF8)
        write(io, hton(UInt16(n)))
    else
        write(io, SMALL_ATOM_UTF8)
        write(io, hton(UInt8(n)))
    end
    write(io, str)
    io
end

function deserialize(io, ::Val{ATOM})
    n = Int(ntoh(read(io, UInt16)))
    Symbol(String(read(io, n)))
end

function deserialize(io, ::Val{ATOM_UTF8})
    n = Int(ntoh(read(io, UInt16)))
    Symbol(String(read(io, n)))
end

function deserialize(io, ::Val{SMALL_ATOM_UTF8})
    n = Int(ntoh(read(io, UInt8)))
    Symbol(String(read(io, n)))
end

function _serialize(io, val::String)
    write(io, BINARY)
    str = Array{UInt8}(val)
    n = length(str)
    n > typemax(UInt32) && throw(ArgumentError("Strings longer than $(typemax(UInt32)) cannot be serialized."))
    write(io, hton(UInt32(n)))
    write(io, str)
    io
end

function deserialize(io, ::Val{BINARY})
    n = Int(ntoh(read(io, UInt32)))
    String(read(io, n))
end

function deserialize(io, ::Val{SMALL_BIG})
    n = Int(read(io, UInt8))
    sign = Int32(read(io, UInt8) == 0 ? 1 : -1)
    arr = Array{UInt8,1}(read(io, n))
    _bignum(n, sign, arr)
end

function deserialize(io, ::Val{LARGE_BIG})
    n = Int(ntoh(read(io, UInt32)))
    sign = Int32(read(io, UInt8) == 0 ? 1 : -1)
    arr = Array{UInt8,1}(read(io, n))
    _bignum(n, sign, arr)
end

function _bignum(n, sign, arr)
    itype = n < 4 ? Int32 : 
            n < 8 ? Int64 :
            n < 16 ? Int128 : BigInt
    sign * dig2int(itype, arr)
end

dig2int(arr) = sum(((i, x),) -> x * 256^(i - 1), pairs(arr))
dig2int(::Type{Int32}, arr) = Int32(dig2int(arr))
dig2int(::Type{Int64}, arr) = sum(((i, x),) -> x * Int64(256)^(i - 1), pairs(arr))
dig2int(::Type{Int128}, arr) = sum(((i, x),) -> x * Int128(256)^(i - 1), pairs(arr))
dig2int(::Type{BigInt}, arr) = sum(((i, x),) -> x * BigInt(256)^(i - 1), pairs(arr))

function _serialize(io, array::AbstractArray)
    if isempty(array)
        write(io, NIL)
        return io
    end

    write(io, LIST)
    n = length(array)
    n > typemax(UInt32) && throw(ArgumentError("Arrays longer than $(typemax(UInt32)) cannot be serialized."))
    write(io, hton(UInt32(n)))
    for el in array
        _serialize(io, el)
    end
    write(io, NIL)
    io
end

function deserialize(io, ::Val{NIL})
    []
end

function deserialize(io, ::Val{LIST})
    n = Int(ntoh(read(io, UInt32)))
    i = 0
    array = []
    while i < n
        tag = read(io, UInt8)
        push!(array, deserialize(io, Val(tag)))
        i += 1
    end
    tail = read(io, UInt8)
    tail != NIL && throw(ArgumentError("Improper lists are not supported."))
    array
end

function _serialize(io, dict::Dict)
    write(io, MAP)
    n = length(dict)
    n > typemax(UInt32) && throw(ArgumentError("Dicts with more than $(typemax(UInt32)) pairs cannot be serialized."))
    write(io, hton(UInt32(n)))
    for (key, value) in dict
        _serialize(io, key)
        _serialize(io, value)
    end
    io
end

function deserialize(io, ::Val{MAP})
    n = Int(ntoh(read(io, UInt32)))
    i = 0
    dict = Dict()
    while i < n
        keytag = read(io, UInt8)
        key = deserialize(io, Val(keytag))
        valuetag = read(io, UInt8)
        value = deserialize(io, Val(valuetag))
        push!(dict, key => value)
        i += 1
    end
    dict
end

function _serialize(io, val::Tuple)
    n = length(val)
    if n > typemax(UInt32)
        throw(ArgumentError("Tuples longer than $(typemax(UInt32)) cannot be serialized."))
    elseif n > typemax(UInt8)
        write(io, LARGE_TUPLE)
        write(io, hton(UInt32(n)))
    else
        write(io, SMALL_TUPLE)
        write(io, hton(UInt8(n)))
    end
    for el in val
        _serialize(io, el)
    end
    io
end

function deserialize(io, ::Val{SMALL_TUPLE})
    n = Int(ntoh(read(io, UInt8)))
    i = 0
    array = []
    while i < n
        tag = read(io, UInt8)
        push!(array, deserialize(io, Val(tag)))
        i += 1
    end
    Tuple(array)
end
    
function deserialize(io, ::Val{LARGE_TUPLE})
    n = Int(ntoh(read(io, UInt32)))
    i = 0
    array = []
    while i < n
        tag = read(io, UInt8)
        push!(array, deserialize(io, Val(tag)))
        i += 1
    end
    Tuple(array)
end

function deserialize(io, ::Val{STRING})
    n = Int(ntoh(read(io, UInt16)))
    i = 0
    array = []
    while i < n
        push!(array, ntoh(read(io, UInt8)))
        i += 1
    end
    array
end

function _serialize(io, ::Nothing)
    write(io, NIL)
    io
end

end # module
