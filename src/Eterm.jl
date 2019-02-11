module Eterm

export serialize, deserialize

const SMALL_INTEGER = UInt8(97)
const INTEGER = UInt8(98)
const NEW_FLOAT = UInt8(70)
const ATOM = UInt8(100)
const ATOM_UTF8 = UInt8(118)
const SMALL_ATOM_UTF8 = UInt8(119)
const BINARY = UInt8(109)
const NIL = UInt8(106)
const LIST = UInt8(108)
const MAP = UInt8(116)

const VERSION = UInt8(131)

function deserialize(io::IOBuffer)
    version = read(io, UInt8)
    version != VERSION && throw(ArgumentError("Unknown external term format version: $(Int(version))."))

    tag = read(io, UInt8)
    deserialize(io, Val(tag))
end
deserialize(binary::Array{UInt8}) = deserialize(IOBuffer(binary))

function serialize(data)
    io = IOBuffer()
    write(io, VERSION)
    take!(serialize(io, data))
end

function serialize(io, val::Integer)
    if val > 0 && val <= typemax(UInt8)
        write(io, SMALL_INTEGER)
        write(io, UInt8(val))
    else
        write(io, INTEGER)
        write(io, hton(Int32(val)))
    end
    io
end

function deserialize(io, ::Val{SMALL_INTEGER})
    Int(read(io, UInt8))
end

function deserialize(io, ::Val{INTEGER})
    ntoh(read(io, Int32))
end

function serialize(io, val::Float64)
    write(io, NEW_FLOAT)
    write(io, hton(val))
    io
end

function deserialize(io, ::Val{NEW_FLOAT})
    ntoh(read(io, Float64))
end

function serialize(io, val::Symbol)
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

function serialize(io, val::String)
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

function serialize(io, array::AbstractArray)
    if isempty(array)
        write(io, NIL)
        return io
    end

    write(io, LIST)
    n = length(array)
    n > typemax(UInt32) && throw(ArgumentError("Arrays longer than $(typemax(UInt32)) cannot be serialized."))
    write(io, hton(UInt32(n)))
    for el in array
        serialize(io, el)
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

function serialize(io, dict::Dict)
    write(io, MAP)
    n = length(dict)
    n > typemax(UInt32) && throw(ArgumentError("Dicts with more than $(typemax(UInt32)) pairs cannot be serialized."))
    write(io, hton(UInt32(n)))
    for (key, value) in dict
        serialize(io, key)
        serialize(io, value)
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
        push!(dict, key=>value)
        i += 1
    end
    dict
end

end # module