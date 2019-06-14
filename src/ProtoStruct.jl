macro proto( name )
    ex = quote
        struct $name{ NT<:NamedTuple{Syms,T} where {Syms,T} }
            properties::NT
        end # struct

        $name(;kwargs...) = $name(kwargs.data)

        function Base.getproperty( o::$name, s::Symbol )
            return getproperty( getfield(o,:properties), s )
        end # function
    end # quote
    esc(ex)
end # macro
