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


import Base.==
==(a::PropDict, b::PropDict) = _dict(a) == _dict(b)


@inline Base.keys(p::PropDict) = keys(_dict(p))

@inline Base.values(p::PropDict) = values(_dict(p))

@inline function Base.getproperty(p::PropDict, s::Symbol)
    if s == :_internal_dict
        getfield(p, :_internal_dict)
    else
        _dict(p)[s]
    end
end

@inline function Base.propertynames(p::PropDict, private::Bool = false)
    names = collect(filter(x -> x isa Symbol, keys(_dict(p))))
    if private
        [names..., :_internal_dict]
    else
        names
    end
end


Base.length(p::PropDict) = length(_dict(p))

Base.getindex(p::PropDict, key) = getindex(_dict(p), key)

Base.setindex!(p::PropDict, value, key) = setindex!(_dict(p), value, key)

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
    d = JSON.Parser.parsefile(filename)

    var_values = Dict{String,String}()
    if subst_pathvar
        var_values["_"] = dirname(filename)
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
