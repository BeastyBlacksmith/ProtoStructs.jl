# ProtoStructs.jl

[![Run tests](https://github.com/BeastyBlacksmith/ProtoStructs.jl/actions/workflows/test.yml/badge.svg)](https://github.com/BeastyBlacksmith/ProtoStructs.jl/actions/workflows/test.yml) ![Codecov](https://codecov.io/gh/beastyblacksmith/ProtoStructs.jl/branch/master/graph/badge.svg)

You are developing a new datastructure and are tired of restarting everytime you change your mind?
`ProtoStructs` lets you have `structs` which behave like they would have been redefined.

Here is how it works:

```julia
using ProtoStructs

@proto @kwdef struct DevType{T}
    a::T = 1
    b::Float64 = 2.0
    c
end
a = DevType(a=1, b=2.0, c="3")
b = DevType(c=:boo)
c = DevType(2, 4.0, nothing)

@proto @kwdef mutable struct DevType{T1, T2}
    a::T1 = 1
    b::T2 = 2.0
    c
end
a = DevType(a=1, b=2.0, c="3")
b = DevType(c=:boo)
c = DevType(2, 4.0, nothing)
```

Redefine at will, but remove the `@proto` macro after developing to ensure correctness and improve performance of your code.

## Compatibility with Revise.jl

For workflows using `Revise.jl` use the `@proto` macro passing `:revisable` as first argument. 

---

For julia `VERSION < v"1.8"` there is also [Redef](https://github.com/FedericoStra/RedefStructs.jl).
