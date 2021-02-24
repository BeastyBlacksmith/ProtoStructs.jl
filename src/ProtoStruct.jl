macro proto( expr )
    if expr.head != Symbol("struct")
        throw(ArgumentError("Expected expression to be a type definition."))
    end

    name = expr.args[2]
    if !(name isa Symbol)
        name = name.args[1]
    end

    field_info = map(expr.args[3].args[2:2:length(expr.args[3].args)]) do field
                        return if field isa Symbol
                            (field, Any)
                        else
                            (field.args[1], field.args[2])
                        end
                    end
    field_names = Tuple(getindex.(field_info, 1))
    # Symbol for Int -> Int64/Int32
    field_types = quote Tuple{$(Symbol.(getindex.(field_info, 2))...)} end
    
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


