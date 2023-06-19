# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


"""
    PropDict <: AbstractDict{Union{Symbol,Int},Any}

PropDicts is a dictionary for that supports

Constructors:

    PropDict(dict::AbstractDict)

    PropDict(key1 => value, key2 => value2, ...)

During construction, keys are automatically converted to `Symbol`s and
`Int`s, values that are dicts are converted to `PropDict`s.

`PropDict` support deep merging:
```julia
x = PropDict(:a => PropDict(:b => 7, :c => 5, :d => 2), :e => "foo")
y = PropDict(:a => PropDict(:c => 42, :d => nothing), :f => "bar")

z = merge(x, y)
@assert z == PropDict(
    :a => PropDict(:b=>7, :d => nothing, :c => 42),
    :e => "foo", :f => "bar"
)

PropDicts.trim_null!(z)
@assert z == PropDict(
    :a => PropDict(:b=>7, :c => 42),
    :e => "foo", :f => "bar"
)
```
, key::Symbol) = MissingProperty(m, key)
Non-exsisting properties can be accessed as instances of
[`PropDicts.MissingProperty`](@ref)). These can be set up a value, this
adds (possibly nested) `PropDict`s to their parent:

```julia
z.foo.bar isa PropDicts.MissingProperty
z.foo.bar = 42
z.foo.bar == 42
```
"""
struct PropDict <: AbstractDict{Union{Symbol,Int},Any}
    _internal_dict::Dict{Union{Symbol,Int},Any}

    PropDict() = new(Dict{Union{Symbol,Int},Any}())

    PropDict(dict::PropDict) = new(_dict(dict))

    PropDict(dict::Dict{Union{Symbol,Int},Any}) = is_props_dict_compatible(dict) ? new(dict) : convert(PropDict, dict)
end
export PropDict

PropDict(dict::AbstractDict) = convert(PropDict, dict)

PropDict(keys_and_values::Pair...) = PropDict(Dict(keys_and_values...))


_dict(p::PropDict) = getfield(p, :_internal_dict)

Base.parent(p::PropDict) = _dict(p)


is_props_dict_compatible(d::AbstractDict) = false

function is_props_dict_compatible(d::Dict{Union{Symbol,Int},Any})
    for (k, v) in d
        if !(isa(k, Symbol) || isa(k, Int))
            return false
        end

        if isa(v, AbstractDict)
            if !is_props_dict_compatible(v)
                return false
            end
        end
    end

    return true
end


_convert_value(x) = x
_convert_value(d::AbstractDict) = PropDict(d)


Base.convert(::Type{PropDict}, d::PropDict) = d

function Base.convert(::Type{PropDict}, d::AbstractDict)
    result = PropDict()

    for (k, v) in d
        k_new = if isa(k, Symbol) || isa(k, Int)
            k
        else
            if isa(k, String)
                if occursin(integer_expr, k)
                    parse(Int, k)
                else
                    Symbol(k)
                end
            else
                throw(ArgumentError("Key type $(typeof(k)) is not supported for PropDict dictionaries"))
            end
        end

        v_new = if isa(v, AbstractDict)
            convert(PropDict, v)
        else
            v
        end

        result[k_new] = v_new
    end

    result
end


Base.convert(::Type{Dict}, p::PropDict) = _dict(p)
Base.convert(::Type{Dict{Union{Symbol,Int}}}, p::PropDict) = _dict(p)
Base.convert(::Type{Dict{Union{Symbol,Int},Any},}, p::PropDict) = _dict(p)


import Base.==
==(a::PropDict, b::PropDict) = _dict(a) == _dict(b)


@inline Base.keys(p::PropDict) = keys(_dict(p))

@inline Base.values(p::PropDict) = values(_dict(p))

@inline function Base.getproperty(p::PropDict, s::Symbol)
    if s == :_internal_dict
        getfield(p, :_internal_dict)
    else
        p[s]
    end
end

@inline Base.setproperty!(p::PropDict, s::Symbol, x) = p[s] = x

@inline function Base.propertynames(p::PropDict, private::Bool = false)
    names = collect(filter(x -> x isa Symbol, keys(_dict(p))))
    if private
        [names..., :_internal_dict]
    else
        names
    end
end


Base.length(p::PropDict) = length(_dict(p))

function Base.getindex(p::PropDict, key)
    d = _dict(p)
    if haskey(d, key)
        d[key]
    else
        MissingProperty(p, key)
    end
end

Base.get!(p::PropDict, key, default) = get!(_dict(p), key, default)

Base.setindex!(p::PropDict, value, key) = setindex!(_dict(p), _convert_value(value), key)

Base.delete!(p::PropDict, key) = delete!(_dict(p), key)

Base.convert(::Type{PropDict}, s::AbstractString) =  PropDict(JSON.parse(s))

Base.print(io::IO, p::PropDict) = JSON.print(io, _dict(p))

Base.iterate(p::PropDict) = iterate(_dict(p))
Base.iterate(p::PropDict, i) = iterate(_dict(p), i)


function Base.merge!(p::PropDict, others::PropDict...)
    PropDict(deepmerge!(_dict(p), map(_dict, (others))...))
    p
end


Base.merge(p::PropDict, others::PropDict...) =
    PropDict(deepmerge(_dict(p), map(_dict, (others))...))


const integer_expr = r"^[+-]?[0-9]+$"




function Base.read(::Type{PropDict}, filename::AbstractString; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false)
    abs_filename = abspath(filename)

    d = JSON.Parser.parsefile(abs_filename)

    var_values = Dict{String,String}()
    if subst_pathvar
        var_values["_"] = dirname(abs_filename)
    end

    if subst_pathvar || subst_env
        substitute_vars!(d, var_values, use_env = true, ignore_missing = false, recursive = true)
    end

    if trim_null
        trim_null!(d)
    end

    PropDict(d)
end


function Base.read(::Type{PropDict}, filenames::Vector{<:AbstractString}; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false)
    p = PropDict()
    for f in filenames
        merge!(p, read(PropDict, f, subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = false))
    end

    if trim_null
        trim_null!(_dict(p))
    end

    p
end



"""
    struct MissingProperty

An instance MissingProperty(parent, key::Symbol) represents the fact the `key`
is missing in `parent`.

Instances of `MissingProperty` support `setindex!` and `setproperty!`, this
will create the `key` in `parent` as a [`PropDict`](@ref).
"""
struct MissingProperty
    _internal_parent::Union{PropDict,MissingProperty}
    _internal_key::Union{Symbol,Int}
end

_internal_parent(m::MissingProperty) = getfield(m, :_internal_parent)
_internal_key(m::MissingProperty) = getfield(m, :_internal_key)

MissingProperty(m::MissingProperty) = MissingProperty(_internal_parent(m), _internal_key(m))

Base.getindex(@nospecialize(m::MissingProperty), @nospecialize(key)) = MissingProperty(m, key)

@inline function Base.getproperty(@nospecialize(m::MissingProperty), s::Symbol)
    if s == :_internal_parent
        getfield(m, :_internal_parent)
    elseif s == :_internal_key
        getfield(m, :_internal_key)
    else
        m[s]
    end
end

_get_or_create_dict(@nospecialize(d::AbstractDict)) = d

function _get_or_create_dict(@nospecialize(m::MissingProperty))
    parent_d = _get_or_create_dict(_internal_parent(m))
    get!(parent_d, _internal_key(m), PropDict())
end

function Base.get!(m::MissingProperty, key, default)
    @nospecialize m key default
    get!(_get_or_create_dict(m), key, default)
end

function Base.setindex!(m::MissingProperty, value, key::Union{Symbol,Int})
    @nospecialize m value key
    _get_or_create_dict(m)[key] = value
end

@inline Base.setproperty!(@nospecialize(m::MissingProperty), key::Symbol, value) = m[key] = value

@inline function Base.propertynames(::MissingProperty, private::Bool = false)
    if private
        (:_internal_parent, :internal_key)
    else
        ()
    end
end


_show_missing_property_impl(io::IO, d::AbstractDict) = show(io, d)
function _show_missing_property_impl(io::IO, m::MissingProperty)
    _show_missing_property_impl(io, _internal_parent(m))
    print(io, ".", _internal_key(m))
end

function Base.show(io::IO, m::MissingProperty)
    print(io, "PropDicts.MissingProperty", "(")
    _show_missing_property_impl(io, m)
    print(io, ")")
end
