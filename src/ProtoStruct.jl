macro proto( name )
    ex = quote
        struct $name{NT<:NamedTuple}
            properties::NT
        end # struct

        $name(;kwargs...) = $name(kwargs.data)

        function Base.getproperty( o::$name, s::Symbol )
            return getproperty( getfield(o, :properties), s )
        end # function

        function Base.propertynames( o::$name )
            return propertynames( getfield(o, :properties) )
        end # function
    end # quote
    esc(ex)
end # macro
