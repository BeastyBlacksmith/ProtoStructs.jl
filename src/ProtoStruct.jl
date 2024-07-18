
const revise_uuid = Base.UUID("295af30f-e4ad-537b-8983-00126c2a3abe")
using Base: nothing_sentinel
const revise_pkgid = Base.PkgId(revise_uuid, "Revise")

const ProtoInfo = @NamedTuple{world::UInt64, paramcount::Int, fields::NamedTuple}
"Definitions of proto structs so we can upgrade instances on demand"
const DEFS = Dict{Symbol, ProtoInfo}()

function checkrev()
    revise_pkgid in keys(Base.loaded_modules) || return false 
    d = @__DIR__ 
    f = splitpath(@__FILE__)[end]
    watched_files = getproperty(Base.loaded_modules[revise_pkgid], :watched_files)
    d in keys(watched_files) || return false
    trackedfiles = watched_files[d].trackedfiles
    return f in keys(trackedfiles)
end

# Base._kwdef! is not available in 1.11
function local_kwdef!(expr, params, calls)
    for (i, ex) in enumerate(expr.args)
        ex isa LineNumberNode && continue
        isconst = ex isa Expr && ex.head == :const
        if isconst
            ex = ex.args[1]
        end
        name = ex
        if name isa Expr && name.head == :(=)
            name = name.args[1]
        end
        if name isa Expr && name.head == :(::)
            name = name.args[1]
        end
        if !(name isa Symbol)
            error("ProtoStructs cannot handle struct field $ex")
        end
        if ex isa Expr && ex.head == :(=)
            # remove assignment from expr
            newexpr = ex.args[1]
            push!(params, Expr(:kw, name, ex.args[2]))
        else
            newexpr = ex
            push!(params, name)
        end
        if isconst
            newexpr = Expr(:const, newexpr)
        end
        expr.args[i] = newexpr
        push!(calls, name)
    end
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
        base_field_types = :(Tuple{$(getindex.(values(field_info), :type)...)})
        field_types = :(Tuple{$((info.isconst ? :($(info.type)) :
            :(Base.RefValue{$(info.type)})
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
    local_kwdef!(expr.args[3], params_ex.args, call_args)
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
    world = UInt64(Base.get_world_counter())
    UNIQ = gensym()

    ex = if ismutable
            quote
                if !@isdefined $name
                    Base.@__doc__ struct $name{$(default_params...)} <: $abstract_type
                        info::Ref{$ProtoStructs.ProtoInfo}
                        properties::Ref{NamedTuple}
                    end
                else
                    if ($abstract_type != Any) && ($abstract_type != Base.supertype($name))
                        error("The supertype of a proto struct is not redefinable. Please restart your julia session.")
                    end
                    $ProtoStructs.cleanup_struct($name, $(Symbol("new_$name")))
                end

                function $(Symbol("new_$name"))($(fields...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names}(($(fields_with_ref...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($ProtoStructs.DEFS[$(QuoteNode(name))]), v)
                end

                function $name($(field_names...))
                    local prop_types = $ProtoStructs.property_types($name, $((:Any for _ in 1:length(type_parameters))...)).parameters[2].parameters
                    # call new_NAME so it can infer the type parameters
                    return $(Symbol("new_$name"))( 
                        $((:($ProtoStructs.convert_field($name, $arg, prop_types[$i]))
                         for (i, arg) in enumerate(field_names))...))
                end

                function $name{$(type_parameter_names...)}($(field_names...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names, $field_types}(($(
                        (info.isconst ? :($ProtoStructs.convert_field($name, $(info.name), $type)) :
                            :(Ref{$type}($ProtoStructs.convert_field($name, $(info.name), $type)))
                         for (type, info) in zip(base_field_types.args[2:end], field_info))...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($ProtoStructs.DEFS[$(QuoteNode(name))]), v)
                end

                function $name($params_ex) where {$(type_parameters...)}
                    $name($(call_args...))
                end

                function $name{$(type_parameter_names...)}($params_ex) where {$(type_parameters...)}
                    $name{$(type_parameter_names...)}($(call_args...))
                end

                function $ProtoStructs.default_for(::$name{$(type_parameter_names...)}, field::Symbol) where {$(type_parameter_names...)}
                    return (;
                            $((Expr(:kw, p.args[1], p.args[2]) for p in params_ex.args if !(p isa Symbol))...)
                            )[field]
                end

                function $ProtoStructs.property_types(::Type{$UNIQ}, $(type_parameter_names...)) where {$UNIQ <: $name}
                    return NamedTuple{$field_names, $base_field_types}
                end

                function Base.getproperty(o::$name, s::Symbol)
                    $ProtoStructs.updateproto(o)
                    p = getproperty(getfield(o, :properties)[], s)
                    s ∈ $const_field_names ? p : p[]
                end

                function Base.setproperty!(o::$name, s::Symbol, v)
                    $ProtoStructs.updateproto(o)
                    p = getproperty(getfield(o, :properties)[], s)
                    if s ∈ $const_field_names
                        error("const field $s of type ", $name, " cannot be changed")
                    else
                        p[] = v
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
                     paramcount=$(length(type_parameters)),
                     fields=$(runtime_field_info(field_info)),
                     )
            end
        else
            quote
                if !@isdefined $name
                    Base.@__doc__ struct $name{$(default_params...)} <: $abstract_type
                        info::Ref{$ProtoStructs.ProtoInfo}
                        properties::Ref{NamedTuple}
                    end
                else
                    if ($abstract_type != Any) && ($abstract_type != Base.supertype($name))
                        error("The supertype of a proto struct is not redefinable. Please restart your julia session.")
                    end
                    $ProtoStructs.cleanup_struct($name, $(Symbol("new_$name")))
                end

                function $(Symbol("new_$name"))($(fields...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names, $field_types}(($(field_names...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($ProtoStructs.DEFS[$(QuoteNode(name))]), v)
                end

                function $name($(field_names...))
                    local prop_types = $ProtoStructs.property_types($name, $((:Any for _ in 1:length(type_parameters))...)).parameters[2].parameters
                    # call new_NAME so it can infer the type parameters
                    return $(Symbol("new_$name"))(
                        $((:($ProtoStructs.convert_field($name, $arg, prop_types[$i]))
                         for (i, arg) in enumerate(field_names))...))
                end

                function $name{$(type_parameter_names...)}($(field_names...)) where {$(type_parameters...)}
                    v = NamedTuple{$field_names, $field_types}(($(
                        (:($ProtoStructs.convert_field($name, $arg, $type))
                         for (type, arg) in zip(field_types.args[2:end], field_names))...),))
                    return $name{$(type_parameter_names...), $(any_params...)}(Ref($ProtoStructs.DEFS[$(QuoteNode(name))]), v)
                end

                function $name($params_ex) where {$(type_parameters...)}
                    $name($(call_args...))
                end

                function $name{$(type_parameter_names...)}($params_ex) where {$(type_parameters...)}
                    $name{$(type_parameter_names...)}($(call_args...))
                end

                function $ProtoStructs.default_for(::$name{$(type_parameter_names...)}, field::Symbol) where {$(type_parameter_names...)}
                    return (;
                            $((Expr(:kw, p.args[1], p.args[2]) for p in params_ex.args if !(p isa Symbol))...)
                            )[field]
                end

                $((:(function $ProtoStructs.convert_field(::Type{$UNIQ}, value::$(info.type), target::Type) where {$UNIQ <: $name, $(type_parameters...)}
                         value
                    end)
                  for info in field_info)...)

                function $ProtoStructs.property_types(::Type{$UNIQ}, $(type_parameter_names...)) where {$UNIQ <: $name}
                    return NamedTuple{$field_names, $field_types}
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
                     paramcount=$(length(type_parameters)),
                     fields=$(runtime_field_info(field_info)),
                     )
            end
        end
    return ex
end

function runtime_field_info(info)
    return :((;
              $((:($(i.name) = (; name = $(QuoteNode(i.name)),
                                isconst = $(i.isconst),
                                hasdefault = $(i.hasdefault),
                                ))
                 for i in info)...),
        ))
end

function getdefault(ex)
    ex isa Expr && ex.head == :kw &&
        return true, ex.args[2]
    ex isa Symbol &&
        return false, nothing
    @warn "Cannot compute default for field $ex"
    return false, nothing
end

function property_types end

function updateproto(o::T) where {T}
    local defs = DEFS[nameof(T)]
    local curtime, paramcount, fields = defs
    local olddefs = getfield(o, :info)[]
    olddefs.world == curtime &&
        return false
    getfield(o, :info)[] = defs
    # get type for old struct's new properties
    local raw_prop_type = property_types(T, T.parameters[1:paramcount]...)
    local prop_types = (; zip(raw_prop_type.parameters[1], raw_prop_type.parameters[2].parameters)...)
    local oldfields = getfield(o, :properties)[]

    getfield(o, :properties)[] = (; (name => updatefield(o, type, fields[name], oldfields)
                                     for (name, type) in pairs(prop_types))...)
    @info "Warning, T has changed"
    return true
end

function default_for end

"""
newtype contains the fully instantiated type for this struct
"""
function updatefield(o, newtype, info, oldfields)
    local err = ""
    local orig_type = newtype
    local default = default_for(o, info.name)

    if !info.isconst
        newtype = Ref{newtype}
    end
    if info.name ∈ keys(oldfields)
        try
            return updatevalue(newtype, oldfields[info.name])
        catch
            err = "Could not convert old value $(oldfields[info.name]) to type $newtype"
        end
    end
    if !info.hasdefault
        try
            default = typemin(orig_type)
            if !isempty(err)
                err = "$err and no default value for field $(info.name), choosing typemin"
            else
                err = "No default value for field $(info.name), choosing typemin"
            end
        catch
            if !isempty(err)
                error("$err and no default value or typemin for field $(info.name)")
            else
                error("No default value or typemin for field $(info.name)")
            end
        end
    elseif !isempty(err)
        err = "$err, using default instead"
    end
    !isempty(err) &&
        @warn err
    return default
end

updatevalue(newtype, value) = convert(newtype, value)
updatevalue(::Type{Ref{T}}, value::Ref{U}) where {T, U} = Ref{T}(updatevalue(T, value[]))
updatevalue(::Type{T}, value::Ref{U}) where {T, U} = updatevalue(T, value[])
updatevalue(::Type{Ref{T}}, value::U) where {T, U} = Ref{T}(updatevalue(T, value))

function convert_field(_, value, target::Type)
    convert(target, value)
end

function firstparam(method)
    local sig = method.sig
    sig isa UnionAll ? Nothing : sig.parameters[1]
end

function cleanup_struct(t::Type, constructor)
    local info = DEFS[nameof(t)]
    local the_methods = collect(methods(t))

    if length(the_methods) >= 1
        Base.delete_method(the_methods[1])
    end
    if length(the_methods) >= 2
        Base.delete_method(the_methods[2])
    end
    local anys = (Any for _ in 1:info.paramcount)
    Base.delete_method.([
        methods(property_types, (Type{t}, anys...))...,
        [m for m in methods(convert_field, (Type{t}, Any, Any)) if firstparam(m) <: t]...,
        methods(constructor)...,
    ])
end
