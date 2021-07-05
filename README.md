# ProtoStructs

[![Build Status](https://travis-ci.com/beastyblacksmith/ProtoStructs.jl.svg?branch=master)](https://travis-ci.com/beastyblacksmith/ProtoStructs.jl)
[![Codecov](https://codecov.io/gh/beastyblacksmith/ProtoStructs.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/beastyblacksmith/ProtoStructs.jl)

You are developing a new datastructure and are tired of restarting everytime you change your mind?
`ProtoStructs` lets you have `structs` which behave like they would have been redifined.

Here is how you do

Like:
```julia
using ProtoStructs

@proto struct DevType
    a::Int = 1
    b::Float64 = 2.0
    c
end
a = DevType(a=1, b=2.0, c="3")
b = DevType(c=:boo)
c = DevType(2, 4.0, nothing)
```

Redefine at will, but please remove the `@proto` macro after developing.

---

There is also [Redef](https://github.com/FedericoStra/RedefStructs.jl)
