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

Acessing non-existing properties will return instances of
[`PropDicts.MissingProperty`](@ref)). When setting the value of missing
properties, parent `PropDict`s are created automatically:

```julia
z.foo.bar isa PropDicts.MissingProperty
z.foo.bar = 42
z.foo.bar == 42
```

`PropDict`s can be read/written to/from JSON files using
[`readprops`](@ref) and [`writeprops`](@ref).

!!! note

    Like with `Base.Dict`, mutating a `PropDict` is *not* thread safe.
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

Base.Dict(p::PropDict) = _dict(p)
Base.Dict{Union{Symbol,Int},Any}(p::PropDict) = _dict(p)


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

Base.empty(::PropDict, ::Type{Union{Symbol,Int}}, ::Type{Any}) = PropDict()

Base.length(p::PropDict) = length(_dict(p))

function Base.getindex(p::PropDict, key)
    d = _dict(p)
    if haskey(d, key)
        d[key]
    else
        MissingProperty(p, key)
    end
end

Base.get(p::PropDict, key, default) = get(_dict(p), key, default)

Base.get!(p::PropDict, key, default) = get!(_dict(p), key, default)

Base.setindex!(p::PropDict, value, key) = setindex!(_dict(p), _convert_value(value), key)

Base.delete!(p::PropDict, key) = delete!(_dict(p), key)

Base.convert(::Type{PropDict}, s::AbstractString) =  PropDict(JSON.parse(s))

Base.print(io::IO, p::PropDict) = JSON.print(io, _dict(p))

Base.iterate(p::PropDict) = iterate(_dict(p))
Base.iterate(p::PropDict, i) = iterate(_dict(p), i)


Base.merge!(p::PropDict, others::PropDict...) = deepmerge!(p, others...)

Base.merge(p::PropDict, others::PropDict...) = deepmerge(p, others...)


const integer_expr = r"^[+-]?[0-9]+$"


"""
    readprops(filename::AbstractString; subst_pathvar::Bool = true, subst_env::Bool = true, trim_null::Bool = true)
    readprops(filenames::Vector{<:AbstractString}; ...)

Read a [`PropDict`](@ref) from a single or multiple JSON files.

If multiple files are given, they are merged into a single `PropDict` using
`merge`.

`subst_pathvar` controls whether `\$_` should be substituted with the
directory path of the/each JSON file within string values (but not field
names).

`subst_env` controls whether `\$ENVVAR` should be substituted with the value of
the each environment variable `ENVVAR` within string values (but not field
names).

`trim_null` controls whether JSON `null` values should be removed entirely.
"""
function readprops end
export readprops

function readprops(filename::AbstractString; subst_pathvar::Bool = true, subst_env::Bool = true, trim_null::Bool = true)
    abs_filename = abspath(filename)
    d = if endswith(abs_filename, ".json")
        JSON.parsefile(abs_filename)
    elseif endswith(abs_filename, ".yaml")
        YAML.load_file(abs_filename)
    end

    var_values = Dict{String,String}()
    if subst_pathvar
        var_values["_"] = dirname(abs_filename)
    end

    if subst_pathvar || subst_env
        substitute_vars!(d, var_values, use_env = subst_env, ignore_missing = false, recursive = true)
    end

    if trim_null
        trim_null!(d)
    end

    PropDict(d)
end


function readprops(filenames::Vector{<:AbstractString}; subst_pathvar::Bool = true, subst_env::Bool = true, trim_null::Bool = true)
    p = PropDict()
    for f in filenames
        merge!(p, readprops(f, subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = false))
    end

    if trim_null
        trim_null!(_dict(p))
    end

    p
end


import Base.read
@deprecate read(
    ::Type{PropDict}, filename::AbstractString; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false
) readprops(filename; subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = trim_null)

@deprecate read(
    ::Type{PropDict}, filenames::Vector{<:AbstractString}; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false
) readprops(filenames; subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = trim_null)


"""
    writeprops(filename, p::PropDict; multiline::Bool = false, indent::Int = 4)

Write [`PropDict`](@ref) `p` to a JSON or YAML file (determined by file extension).
"""
function writeprops end
export writeprops

function writeprops(io::IO, p::PropDict; multiline::Bool = false, indent::Int = 4, format::Symbol = :json)
    if format == :yaml
        YAML.write(io, _dict(p))
    elseif multiline
        JSON.print(io, p, indent)
    else
        JSON.print(io, p)
    end
end

function writeprops(filename::AbstractString, p::PropDict; kwargs...)
    abs_filename = abspath(filename)
    format = if endswith(abs_filename, ".yaml") || endswith(abs_filename, ".yml")
        :yaml
    else
        :json
    end
    open(filename, "w") do io
        writeprops(io, p; format=format, kwargs...)
    end
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

Base.get(@nospecialize(m::MissingProperty), @nospecialize(key), default) = default

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
