macro proto( name )
    quote
        struct $name{ NT<:NamedTuple{Syms,T} where {Syms,T} }
            proerties::NT
        end # struct
    end # quote
end # macro
