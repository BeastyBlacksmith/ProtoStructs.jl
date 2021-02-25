macro proto( expr )
    if expr.head != Symbol("struct")
        throw(ArgumentError("Expected expression to be a type definition."))
    end

    name = expr.args[2]
    type_parameters = nothing
    if !(name isa Symbol)
        type_parameters = name.args[2:end]
        name = name.args[1]
        type_parameter_names = map(type_parameters) do t
                                    if t isa Symbol
                                        t
                                    else
                                        t.args[1]
                                    end
                                end
    end

    fields = expr.args[3].args[2:2:length(expr.args[3].args)]
    field_info = map(fields) do field
                        return if field isa Symbol
                            (field, Any)
                        else
                            (field.args[1], field.args[2])
                        end
                    end
    field_names = Tuple(getindex.(field_info, 1))
    field_types = quote Tuple{$(getindex.(field_info, 2)...)} end
    
    ex = quote
            if !@isdefined $name
                struct $name{NT<:NamedTuple}
                    properties::NT
                end # struct
            end # if
            
            if $(type_parameters) === nothing
                $name(args...) = $name(NamedTuple{$field_names, $field_types}(args))
            else
                $name($(fields...)) where {$(type_parameters...)} = $name(NamedTuple{$field_names, $field_types}(($(field_names...),)))
            end
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





