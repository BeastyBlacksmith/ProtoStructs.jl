macro proto( name )
    quote
        struct $name{ NT<:NamedTuple{Syms,T} where {Syms,T} }
            proerties::NT
        end # struct

        $(esc(name))(;kwargs...) = $(esc(name))(kwargs.data)
    end # quote
end # macro
