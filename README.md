# ProtoStructs

[![Build Status](https://travis-ci.com/beastyblacksmith/ProtoStructs.jl.svg?branch=master)](https://travis-ci.com/beastyblacksmith/ProtoStructs.jl)
[![Codecov](https://codecov.io/gh/beastyblacksmith/ProtoStructs.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/beastyblacksmith/ProtoStructs.jl)

You are developing a new datastructure and are tired of restarting everytime you change your mind?
`ProtoStructs` lets you have `structs` which can have any fields at construction.

Like:
```julia
using ProtoStructs

@proto DevType
a = DevType(a=1, b=2.0, c="3")
b = DevType(d=complex(1), e=true)
```

It is actually just a typed `NamedTuple`.

