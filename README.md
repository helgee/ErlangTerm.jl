# ErlangTerm

*(De-)serialize Julia data in Erlang's external term format*

[![Build Status](https://github.com/helgee/ErlangTerm.jl/workflows/CI/badge.svg?branch=master)](https://github.com/helgee/ErlangTerm.jl/actions)
[![Coverage](https://codecov.io/gh/helgee/ErlangTerm.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/helgee/ErlangTerm.jl)

**ErlangTerm.jl** teaches Julia to talk to BEAM-based languages (Erlang, Elixir, ...) in their native tongue,
the [Erlang external term format](http://erlang.org/doc/apps/erts/erl_ext_dist.html).
The following data types are supported:

- `Int` <-> `Integer`
- `Float64` <-> `Float`
- `Symbol` <-> `Atom`
- `Tuple` <-> `Tuple`
- `Array` <-> `List`
- `Dict` <-> `Map`

## Installation

The package can be installed through Julia's package manager:

```julia
julia> import Pkg; Pkg.add("ErlangTerm")
```

## Usage

```julia
using ErlangTerm

# Take a Julia data structure...
d = Dict(:erlang => Dict(:id => 1, :greeting => "Hello, Erlang!"),
         :elixir => Dict(:id => 2, :greeting => "Hello, Elixir!"))

# ...serialize it...
binary = serialize(d)

# ...and deserialize it!
d1 = deserialize(binary)
```
