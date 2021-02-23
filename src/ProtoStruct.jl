macro proto( expr )
    if expr.head != Symbol("struct")
        throw(ArgumentError("Expected expression to be a type definition."))
    end

    name = expr.args[2]
    if !(name isa Symbol)
        name = name.args[1]
    end

    field_names = Tuple(expr.args[3].args[i].args[1] for i in 2:2:length(expr.args[3].args))
    field_types = quote Tuple{$((expr.args[3].args[i].args[2] for i in 2:2:length(expr.args[3].args))...)} end
    
    ex = quote
            if !@isdefined $name
                struct $name{NT<:NamedTuple}
                    properties::NT
                end # struct
            end # if
        
        $name(args...) = $name(NamedTuple{$field_names, $field_types}(args))
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


