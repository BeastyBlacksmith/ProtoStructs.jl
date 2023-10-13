
macro proto( expr )
    if expr.head == :macrocall && expr.args[1] == Symbol("@kwdef")
        expr = expr.args[3]
    end

    if expr.head != Symbol("struct")
        throw(ArgumentError("Expected expression to be a type definition."))
    end
    ismutable = expr.args[1]

    name = expr.args[2]

    if !(name isa Symbol) && name.head == :<:
        abstract_type = name.args[2]
        name = name.args[1]
    else
        abstract_type = :(Any)
    end

    type_parameters = nothing
    type_parameter_names = []
    type_parameter_types = []
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
    end

    const_fields = []
    fields = map(expr.args[3].args[2:2:length(expr.args[3].args)]) do field
                    if field isa Symbol
                        push!(const_fields, false)
                        return field
                    end
                    is_const = field.head == :const
                    if is_const
                        field = field.args[1]
                    end
                    push!(const_fields, is_const)
                    if field.head == :(=)
                        return field.args[1]
                    else
                        return field
                    end
                end
    i = 0
    field_info = map(fields) do field
                        i += 1
                        if field isa Symbol
                            return (field, Any, const_fields[i])
                        else
                            return (field.args[1], field.args[2], const_fields[i])
                        end
                    end

    field_names = Tuple(getindex.(field_info, 1))
    const_field_names = [f for (f, fi) in zip(field_names, field_info) if fi[3] == true]
    if ismutable
        field_types = :(Tuple{$((:(Base.RefValue{<:$x}) for x in getindex.(field_info, 2))...)})
        fields_with_ref = (:($x=Ref($x)) for x in field_names)
    else
        field_types = :(Tuple{$(getindex.(field_info, 2)...)})
    end

    field_subtype_info = map(getindex.(field_info, 2)) do ft
        if ft in type_parameter_names
            return type_parameter_types[ft]
        else
            return ft
        end
    end

    params_ex = Expr(:parameters)
    call_args = Any[]

    Base._kwdef!(expr.args[3], params_ex.args, call_args)

    # remove escapes
    params_ex.args = map(params_ex.args) do ex
        if ex isa Symbol return ex end
        ex.args[2] = ex.args[2].args[1]
        ex
    end

    ex = if ismutable
            quote
                if !@isdefined $name
                    struct $name{NT<:NamedTuple} <: $abstract_type
                        properties::NT
                    end
                else
                    the_methods = collect(methods($name))
                    Base.delete_method(the_methods[1])
                    Base.delete_method(the_methods[3])
                end

                $(
                    if type_parameters === nothing
                        :( $name(args...) = $name(NamedTuple{$field_names, $field_types}(Ref.(args))) )
                    else
                        :( $name($(fields...)) where {$(type_parameters...)} = $name(NamedTuple{$field_names, $field_types}(($(fields_with_ref...),))) )
                    end
                )

                function $name($params_ex)
                    $name($(call_args...))
                end

                function Base.getproperty( o::$name, s::Symbol )
                    return getindex(getfield(o, :properties), s)[]
                end

                function Base.setproperty!( o::$name, s::Symbol, v )
                    if s in $const_field_names
                        error("const field ", s, " of type ", $name, " cannot be changed")
                    end
                    getindex(getfield(o, :properties), s)[] = v
                end

                function Base.propertynames( o::$name )
                    return propertynames( getfield(o, :properties) )
                end
            end
        else
            quote
                if !@isdefined $name
                    struct $name{NT<:NamedTuple} <: $abstract_type
                        properties::NT
                    end
                else
                    the_methods = collect(methods($name))
                    Base.delete_method(the_methods[1])
                    Base.delete_method(the_methods[3])
                end

                $(
                    if type_parameters === nothing
                        :( $name(args...) = $name(NamedTuple{$field_names, $field_types}(args)) )
                    else
                        :( $name($(fields...)) where {$(type_parameters...)} = $name(NamedTuple{$field_names, $field_types}(($(field_names...),))) )
                    end
                )

                function $name($params_ex)
                    $name($(call_args...))
                end

                function Base.getproperty( o::$name, s::Symbol )
                    return getproperty( getfield(o, :properties), s )
                end

                function Base.propertynames( o::$name )
                    return propertynames( getfield(o, :properties) )
                end
            end
        end
    ex |> esc
end
