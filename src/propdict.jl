# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


"""
    PropDict <: AbstractDict{Union{Symbol,Int},Any}

A dictionary with `Symbol` and `Int` keys that supports property-based
access and deep merging.

Constructors:

    PropDict(dict::AbstractDict)

    PropDict(key1 => value1, key2 => value2, ...)

    PropDict(key1 = value1, key2 = value2, ...)

Also see [`@propdict`](@ref) for construction from named-tuple syntax.

Keys are automatically converted to `Symbol`s and `Int`s: string keys that
represent an integer become `Int`s, other string keys become `Symbol`s. The
same conversion is applied when getting, setting or deleting entries. Values
that are dicts are converted to `PropDict`s.

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

`PropDict`s can be read/written to/from JSON and YAML files using
[`readprops`](@ref) and [`writeprops`](@ref). Note that the Julia packages
[JSON](https://github.com/JuliaIO/JSON.jl) resp.
[YAML](https://github.com/JuliaData/YAML.jl) need to be loaded first.

!!! note

    Like with `Base.Dict`, mutating a `PropDict` is *not* thread safe.
"""
struct PropDict <: AbstractDict{Union{Symbol,Int},Any}
    _internal_dict::Dict{Union{Symbol,Int},Any}

    PropDict(dict::PropDict) = new(_dict(dict))

    PropDict(dict::Dict{Union{Symbol,Int},Any}) = is_props_dict_compatible(dict) ? new(dict) : convert(PropDict, dict)
end
export PropDict

PropDict(dict::AbstractDict) = convert(PropDict, dict)

function PropDict(keys_and_values::Pair...; kwargs...)
    p = PropDict(Dict{Union{Symbol,Int},Any}())
    for (k, v) in keys_and_values
        p[k] = v
    end
    for (k, v) in kwargs
        p[k] = v
    end
    p
end


"""
    @propdict (key1 = value1, key2 = (key3 = value3,), ...)

Construct a [`PropDict`](@ref) from named-tuple syntax.

Nested named-tuple literals become nested `PropDict`s:

```julia
p = @propdict (a = (b = 7, c = 5), e = "foo")
p.a.b == 7
```

Like in named tuples, a nested single-entry literal needs a trailing
comma (`(b = 7,)`) or semicolon form (`(; b = 7)`).
"""
macro propdict(expr)
    _propdict_expr(expr)
end
export @propdict


const _propdict_syntax_error = "@propdict expects named-tuple syntax like (a = 1, b = (c = 2,))"

function _propdict_expr(@nospecialize ex)
    isa(ex, Expr) || throw(ArgumentError(_propdict_syntax_error))

    entries = if ex.head == :tuple
        if length(ex.args) == 1 && isa(only(ex.args), Expr) && (only(ex.args)::Expr).head == :parameters
            (only(ex.args)::Expr).args
        else
            ex.args
        end
    elseif ex.head == :(=)
        [ex]
    else
        throw(ArgumentError(_propdict_syntax_error))
    end

    entry_pairs = map(entries) do entry
        if !(isa(entry, Expr) && entry.head in (:(=), :kw) && isa(entry.args[1], Symbol))
            throw(ArgumentError(_propdict_syntax_error))
        end
        k, v = entry.args[1], entry.args[2]
        :($(QuoteNode(k)) => $(_is_namedtuple_expr(v) ? _propdict_expr(v) : esc(v)))
    end

    Expr(:call, PropDict, entry_pairs...)
end

function _is_namedtuple_expr(@nospecialize ex)
    isa(ex, Expr) && ex.head == :tuple || return false
    if length(ex.args) == 1 && isa(only(ex.args), Expr) && (only(ex.args)::Expr).head == :parameters
        all(a -> isa(a, Expr) && a.head == :kw && isa(a.args[1], Symbol), (only(ex.args)::Expr).args)
    else
        !isempty(ex.args) && all(a -> isa(a, Expr) && a.head == :(=) && isa(a.args[1], Symbol), ex.args)
    end
end


_dict(p::PropDict) = getfield(p, :_internal_dict)

Base.parent(p::PropDict) = _dict(p)

Base.Dict(p::PropDict) = _dict(p)
Base.Dict{Union{Symbol,Int},Any}(p::PropDict) = _dict(p)


is_props_dict_compatible(d::AbstractDict) = false

is_props_dict_compatible(d::Dict{Union{Symbol,Int},Any}) = all(_is_compatible_value, values(d))

_is_compatible_value(@nospecialize x) = true
_is_compatible_value(d::AbstractDict) = isa(d, PropDict)


_convert_value(x) = x
_convert_value(d::AbstractDict) = PropDict(d)


_props_key(key::Symbol) = key
_props_key(key::Int) = key
_props_key(key::Integer) = Int(key)

const integer_expr = r"^[+-]?[0-9]+$"

_props_key(key::AbstractString) =
    occursin(integer_expr, key) ? something(tryparse(Int, key), Symbol(key)) : Symbol(key)

_props_key(@nospecialize key) = key


Base.convert(::Type{PropDict}, d::PropDict) = d

function Base.convert(::Type{PropDict}, d::AbstractDict)
    result = PropDict()

    for (k, v) in d
        k_new = _props_key(k)
        if !isa(k_new, Union{Symbol,Int})
            throw(ArgumentError("Key type $(typeof(k)) is not supported for PropDict dictionaries"))
        end
        result[k_new] = v
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
    k = _props_key(key)
    if haskey(d, k)
        d[k]
    elseif isa(k, Union{Symbol,Int})
        MissingProperty(p, k)
    else
        throw(KeyError(key))
    end
end

Base.get(p::PropDict, key, default) = get(_dict(p), _props_key(key), default)
Base.get(f::Base.Callable, p::PropDict, key) = get(f, _dict(p), _props_key(key))

Base.get!(p::PropDict, key, default) = get!(() -> _convert_value(default), _dict(p), _props_key(key))
Base.get!(f::Base.Callable, p::PropDict, key) = get!(() -> _convert_value(f()), _dict(p), _props_key(key))

Base.setindex!(p::PropDict, value, key) = setindex!(_dict(p), _convert_value(value), _props_key(key))

Base.haskey(p::PropDict, key) = haskey(_dict(p), _props_key(key))

Base.getkey(p::PropDict, key, default) = getkey(_dict(p), _props_key(key), default)

Base.delete!(p::PropDict, key) = (delete!(_dict(p), _props_key(key)); p)

Base.pop!(p::PropDict, key) = pop!(_dict(p), _props_key(key))
Base.pop!(p::PropDict, key, default) = pop!(_dict(p), _props_key(key), default)

Base.empty!(p::PropDict) = (empty!(_dict(p)); p)

Base.copy(p::PropDict) = PropDict(copy(_dict(p)))

Base.sizehint!(p::PropDict, n::Integer) = (sizehint!(_dict(p), n); p)

Base.iterate(p::PropDict) = iterate(_dict(p))
Base.iterate(p::PropDict, i) = iterate(_dict(p), i)


deepmerge(p::PropDict, others::AbstractDict...) = _deepmerge_into!(PropDict(), p, others...)

Base.merge!(p::PropDict, others::AbstractDict...) = deepmerge!(p, others...)

Base.merge(p::PropDict, others::AbstractDict...) = deepmerge(p, others...)


"""
    readprops(filename::AbstractString; subst_pathvar::Bool = true, subst_env::Bool = true, trim_null::Bool = true)
    readprops(filenames::Vector{<:AbstractString}; ...)

Read a [`PropDict`](@ref) from a single or multiple files.

`readprops` supports JSON and YAML files. Note that the Julia packages
[JSON](https://github.com/JuliaIO/JSON.jl) resp.
[YAML](https://github.com/JuliaData/YAML.jl) need to be loaded first.

If multiple files are given, they are merged into a single `PropDict` using
`merge`.

`subst_pathvar` controls whether `\$_` should be substituted with the
directory path of the/each file within string values (but not field
names).

`subst_env` controls whether `\$ENVVAR` should be substituted with the value of
the each environment variable `ENVVAR` within string values (but not field
names).

`trim_null` controls whether JSON/YAML `null` values should be removed
entirely.
"""
function readprops end
export readprops


function readprops(filename::AbstractString; subst_pathvar::Bool = true, subst_env::Bool = true, trim_null::Bool = true)
    abs_filename = abspath(filename)
    format = _format_from_filename(String(abs_filename))
    d = _read_from(Val(format), abs_filename)

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

function _read_from(fmt_val::Val, source)
    format = only(typeof(fmt_val).parameters)
    if format isa Symbol
        throw(ErrorException("Reading PropDicts from format $format requires package $format to be loaded, e.g. via `import $format`"))
    else
        throw(ArgumentError("Invalid input format `$format`, must be a symbol like `:JSON` or `:YAML`"))
    end
end

function _format_from_filename(filename::String)
    if endswith(filename, ".json")
        return :JSON
    elseif endswith(filename, ".yaml") || endswith(filename, ".yml")
        return :YAML
    else
        throw(ArgumentError("Unsupported file format for file \"$filename\", expected a \".json\", \".yaml\" or \".yml\" file extension"))
    end
end


import Base.read
@deprecate read(
    ::Type{PropDict}, filename::AbstractString; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false
) readprops(filename; subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = trim_null)

@deprecate read(
    ::Type{PropDict}, filenames::Vector{<:AbstractString}; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false
) readprops(filenames; subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = trim_null)


"""
    writeprops(io::IO, p::PropDict; multiline::Bool = true, indent::Int = -1)
    writeprops(filename, p::PropDict; format = :JSON, multiline::Bool = true, indent::Int = -1)

Write [`PropDict`](@ref) `p` to JSON file `filename`.

`writeprops` supports JSON and YAML files. Note that the Julia packages
[JSON](https://github.com/JuliaIO/JSON.jl) resp.
[YAML](https://github.com/JuliaData/YAML.jl) need to be loaded first.

`multiline = false` is not supported for YAML files.

Use `indent = -1` for default indentation in multiline mode.
"""
function writeprops end
export writeprops

function writeprops(io::IO, p::PropDict; format = :JSON, multiline::Bool = true, indent::Integer = -1)
    _write_to(Val(format), io, p, multiline, Int(indent))
end

function writeprops(filename::AbstractString, p::PropDict; format::Symbol = _format_from_filename(String(abspath(filename))), kwargs...)
    open(filename, "w") do io
        writeprops(io, p; format = format, kwargs...)
    end
end

function _write_to(fmt_val::Val, io::IO, p::PropDict, multiline::Bool, indent::Int)
    format = only(typeof(fmt_val).parameters)
    if format isa Symbol
        throw(ErrorException("Writing PropDicts to format $(format) requires package $format to be loaded, e.g. via `import $format`"))
    else
        throw(ArgumentError("Invalid output format `$format`, must be a symbol like `:JSON` or `:YAML`"))
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
        (:_internal_parent, :_internal_key)
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
