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
        type_parameter_types = map(type_parameters) do t
                                    if t isa Symbol
                                        :Any
                                    else
                                        t.args[2]
                                    end
                                end
        type_parameter_types = Dict( type_parameter_names[i] => type_parameter_types[i] for i in eachindex(type_parameters))
        @show type_parameters
        @show type_parameter_types
    end

    fields = expr.args[3].args[2:2:length(expr.args[3].args)]
    @show fields
    field_info = map(fields) do field
                        return if field isa Symbol
                            (field, Any)
                        else
                            (field.args[1], field.args[2])
                        end
                    end
    field_names = Tuple(getindex.(field_info, 1))
    field_types = quote Tuple{$(getindex.(field_info, 2)...)} end
    field_subtype_info = map(getindex.(field_info, 2)) do ft
        if ft in type_parameter_names
            return type_parameter_types[ft]
        else
            return ft
        end
    end
    
    ex = quote
            if !@isdefined $name
                struct $name{NT<:NamedTuple}
                    properties::NT
                end # struct
            else
                the_methods = collect(methods($name))
                Base.delete_method(the_methods[1])
                Base.delete_method(the_methods[3])
            end # if
            
            if $(type_parameters) === nothing
                $name(args...) = $name(NamedTuple{$field_names, $field_types}(args))
            else
                $name($(fields...)) where {$(type_parameters...)} = $name(NamedTuple{$field_names, $field_types}(($(field_names...),)))
            end
            
            function $name(;kwargs...)
                if length(kwargs) != $(length(fields))
                    throw(MethodError("Too few or too many fields."))
                end
                for kw in kwargs
                    kw_ind = findfirst(==(kw.first), $field_names)
                    if kw_ind === nothing
                        throw(MethodError("Wrong field $(kw.first)"))
                    end
                    if !(typeof(kw.second) <: getindex(tuple($(field_subtype_info...)), kw_ind))
                        throw(MethodError("Expeceted type $(getindex($field_types, kw_ind)) for field $(kw.first). Got $(typeof(kw.second))"))
                    end
                end
                $name(kwargs.data)
            end

            function Base.getproperty( o::$name, s::Symbol )
                return getproperty( getfield(o, :properties), s )
            end # function

            function Base.propertynames( o::$name )
                return propertynames( getfield(o, :properties) )
            end # function
        end # quote
    esc(ex)
end # macro






