
const revise_uuid = Base.UUID("295af30f-e4ad-537b-8983-00126c2a3abe")
const revise_pkgid = Base.PkgId(revise_uuid, "Revise")

"Definitions of proto structs so we can upgrade instances on demand"
const DEFS = Dict{Symbol, @NamedTuple{world::UInt64, fields::NamedTuple}}()

function checkrev()
    revise_pkgid in keys(Base.loaded_modules) || return false 
    d = @__DIR__ 
    f = splitpath(@__FILE__)[end]
    watched_files = getproperty(Base.loaded_modules[revise_pkgid], :watched_files)
    d in keys(watched_files) || return false
    trackedfiles = watched_files[d].trackedfiles
    return f in keys(trackedfiles)
end

macro proto(expr)
    if checkrev()
        @eval __module__ $(_proto(expr))
        return
    else
        return esc(_proto(expr))
    end
end

function _proto(expr)
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

    type_parameters = []
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
    field_info = (; (map(fields) do field
                        i += 1
                        if field isa Symbol
                            return field => (; name=field, type=Any, isconst=!ismutable || const_fields[i])
                        else
                            return field.args[1] => (; name=field.args[1], type=field.args[2], isconst=!ismutable || const_fields[i])
                        end
                     end)...,
                  )

    field_names = keys(field_info)
    const_field_names = [info.name for info in field_info if info.isconst]

    if ismutable
        field_types = :(Tuple{$((info.isconst ? :($(info.type) where {$(info.type)}) :
            :(Base.RefValue{$(info.type)} where {$(info.type)})
                                 for info in field_info)...)})
        fields_with_ref = (x in const_field_names ? :($x=$x) : (:($x=Ref($x)))
                           for x in field_names)
    else
        field_types = :(Tuple{$(getindex.(values(field_info), :type)...)})
    end

    # UNUSED
    #field_subtype_info = map(getindex.(field_info, 2)) do ft
    #    if ft in type_parameter_names
    #        return type_parameter_types[ft]
    #    else
    #        return ft
    #    end
    #end

    params_ex = Expr(:parameters)
    call_args = Any[]

    Base._kwdef!(expr.args[3], params_ex.args, call_args)

    # remove escapes
    params_ex.args = map(params_ex.args) do ex
        if ex isa Symbol return ex end
        ex.args[2] = ex.args[2].args[1]
        ex
    end

    default_params = [Symbol("P", i) for i in 1:15]
    N_any_params = length(default_params) - length(type_parameter_names)
    N_any_params <= 0 && error("The number of parameters of the proto struct is too high")
    any_params = [:(Any) for _ in 1:N_any_params]
    # merge default values into field_info
    field_info =
        (;
         (name => (; name, type, isconst, hasdefault, default)
          for ((name, type, isconst), (hasdefault, default)) in
              zip(field_info, getdefault.(params_ex.args)))...,
         )
    world = Base.get_world_counter()

    ex = if ismutable
            quote
                if !@isdefined $name
                    Base.@__doc__ struct $name{$(default_params...)} <: $abstract_type
                        world::Ref{UInt64}
                        properties::Ref{NamedTuple}
                    end
                else
                    if ($abstract_type != Any) && ($abstract_type != Base.supertype($name))
                        error("The supertype of a proto struct is not redefinable. Please restart your julia session.")
                    end
                    the_methods = collect(methods($name))
                    if length(the_methods) >= 1
                        Base.delete_method(the_methods[1])
                    end
                    if length(the_methods) >= 2
                        Base.delete_method(the_methods[2])
                    end
                end

                function $name($(fields...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names}(($(fields_with_ref...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($world), v)
                end

                function $name{$(type_parameter_names...)}($(fields...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names}(($(fields_with_ref...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($world), v)
                end

                function $name($params_ex)
                    return $name($((cvt(field_info, arg, type_parameter_names) for arg in call_args)...))
                end

                function $name{$(type_parameter_names...)}($params_ex) where {$(type_parameters...)}
                    $name{$(type_parameter_names...)}($((cvt(field_info, arg, type_parameter_names)
                                                         for arg in call_args)...))
                end

                function Base.getproperty(o::$name, s::Symbol)
                    $ProtoStructs.updateproto(o)
                    p = getproperty(getfield(o, :properties)[], s)
                    if p isa Base.RefValue
                        p[]
                    else
                        p
                    end
                end

                function Base.setproperty!(o::$name, s::Symbol, v)
                    $ProtoStructs.updateproto(o)
                    p = getproperty(getfield(o, :properties)[], s)
                    if p isa Base.RefValue
                        p[] = v
                    else
                        error("const field $s of type ", $name, " cannot be changed")
                    end
                end

                function Base.propertynames(o::$name)
                    $ProtoStructs.updateproto(o)
                    return propertynames(getfield(o, :properties)[])
                end

                function Base.show(io::IO, o::$name)
                    $ProtoStructs.updateproto(o)
                    vals = join([x isa Base.RefValue ? (x[] isa String ? "\"$(x[])\"" : x[]) : x for x in getfield(o, :properties)[]], ", ")
                    params = typeof(o).parameters[1:end-$N_any_params]
                    if isempty(params)
                        print(io, string($name), "($vals)")
                    else
                        print(io, string($name, "{", join(params, ", "), "}"), "($vals)")
                    end
                end
                $ProtoStructs.DEFS[$(QuoteNode(name))] =
                    (;
                     world=$world,
                     fields=$(runtime_field_info(field_info, type_parameter_names)),
                     )
            end
        else
            quote
                if !@isdefined $name
                    Base.@__doc__ struct $name{$(default_params...)} <: $abstract_type
                        world::Ref{UInt64}
                        properties::Ref{NamedTuple}
                    end
                else
                    if ($abstract_type != Any) && ($abstract_type != Base.supertype($name))
                        error("The supertype of a proto struct is not redefinable. Please restart your julia session.")
                    end
                    the_methods = collect(methods($name))
                    if length(the_methods) >= 1
                        Base.delete_method(the_methods[1])
                    end
                    if length(the_methods) >= 2
                        Base.delete_method(the_methods[2])
                    end
                end

                function $name($(fields...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names, $field_types}(($(field_names...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($world), v)
                end

                function $name{$(type_parameter_names...)}($(fields...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names, $field_types}(($(field_names...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($world), v)
                end

                function $name($params_ex)
                    return $name($((cvt(field_info, arg, type_parameter_names) for arg in call_args)...))
                end

                function $name{$(type_parameter_names...)}($params_ex) where {$(type_parameters...)}
                    $name{$(type_parameter_names...)}($((cvt(field_info, arg, type_parameter_names)
                                                         for arg in call_args)...))
                end

                function Base.getproperty(o::$name, s::Symbol)
                    $ProtoStructs.updateproto(o)
                    return getproperty(getfield(o, :properties)[], s)
                end

                function Base.propertynames(o::$name)
                    $ProtoStructs.updateproto(o)
                    return propertynames(getfield(o, :properties)[])
                end

                function Base.show(io::IO, o::$name)
                    $ProtoStructs.updateproto(o)
                    vals = join([x isa String ? "\"$x\"" : x for x in getfield(o, :properties)[]], ", ")
                    params = typeof(o).parameters[1:end-$N_any_params]
                    if isempty(params)
                        print(io, string($name), "($vals)")
                    else
                        print(io, string($name, "{", join(params, ", "), "}"), "($vals)")
                    end
                end
                $ProtoStructs.DEFS[$(QuoteNode(name))] =
                    (;
                     world=$world,
                     fields=$(runtime_field_info(field_info, type_parameter_names)),
                     )
            end
        end
    return ex
end

function cvt(info, arg, params)
    if info[arg].type ∈ params
        return arg
    else
        return :(convert($(info[arg].type), $arg))
    end
end

function runtime_field_info(info, params)
    return :((;
              $((:($(i.name) = (; name = $(QuoteNode(i.name)),
                            type = $(protofieldtype(i.type, params)), isconst = $(i.isconst),
                            hasdefault = $(i.hasdefault), default = $(i.default)))
                 for i in info)...),
        ))
end

protofieldtype(type, params) = type ∈ params ? findfirst(==(type), params) : type

type_params(names) = :((; $((:($name = $name) for name in names)...) ))

function getdefault(ex)
    ex isa Expr && ex.head == :kw &&
        return true, ex.args[2]
    ex isa Symbol &&
        return false, nothing
    @warn "Cannot compute default for field $ex"
    return false, nothing
end

function updateproto(o::T) where {T}
    local curtime, fields = DEFS[nameof(T)]
    getfield(o, :world)[] == curtime &&
        return false
    local oldfields = getfield(o, :properties)[]
    getfield(o, :properties)[] = (; (summary.name => updatefield(o, oldfields, summary) for summary in fields)...)
    println("Warning, T has changed")
    getfield(o, :world)[] = curtime
    return true
end

function updatefield(o, oldfields, info)
    local err = ""
    local orig_type = info.type

    if info.type isa Integer
        info.type = typeof(o).parameters[info.type]
    end
    if !info.isconst
        info.type = Ref{info.type}
    end
    if info.name ∈ keys(oldfields)
        try
            return updatevalue(info.type, oldfields[info.name])
        catch
            err = "Could not convert old value $(oldfields[info.name]) to type $info.type"
        end
    end
    if !info.hasdefault
        try
            info.default = typemin(orig_type)
            if !isempty(err)
                err = "$err and no default value for field $info.name, choosing typemin"
            else
                err = "No default value for field $info.name, choosing typemin"
            end
        catch
            if !isempty(err)
                error("$err and no default value or typemin for field $info.name")
            else
                error("No default value or typemin for field $info.name")
            end
        end
    elseif !isempty(err)
        err = "$err, using default instead"
    end
    !isempty(err) &&
        @warn err
    return info.default
end

updatevalue(newtype, value) = convert(newtype, value)
updatevalue(::Type{Ref{T}}, value::Ref{U}) where {T, U} = Ref{T}(updatevalue(T, value[]))
updatevalue(::Type{T}, value::Ref{U}) where {T, U} = updatevalue(T, value[])
updatevalue(::Type{Ref{T}}, value::U) where {T, U} = Ref{T}(updatevalue(T, value))
