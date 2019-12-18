# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

export PropDict

struct PropDict
    _internal_dict::Dict{Any,Any}

    PropDict() = new(Dict{Any,Any}())

    function PropDict(dict::AbstractDict; auto_convert::Bool = true)
        if auto_convert
            new(is_props_dict(dict) ? dict : to_props_dict(dict))
        else
            new(dict)
        end
    end
end


_dict(p::PropDict) = getfield(p, :_internal_dict)

Base.parent(p::PropDict) = _dict(p)


import Base.==
==(a::PropDict, b::PropDict) = _dict(a) == _dict(b)

Base.convert(::Type{PropDict}, s::AbstractString) =  PropDict(JSON.parse(s))

Base.print(io::IO, p::PropDict) = JSON.print(io, _dict(p))


function Base.merge!(p::PropDict, others::PropDict...)
    PropDict(deepmerge!(_dict(p), map(_dict, (others))...))
    p
end


Base.merge(p::PropDict, others::PropDict...) =
    PropDict(deepmerge(_dict(p), map(_dict, (others))...))


const integer_expr = r"^[+-]?[0-9]+$"


function is_props_dict(d::Dict{Any,Any})
    for (k, v) in d
        if !(isa(k, Symbol) || isa(k, Int))
            return false
        end

        if isa(v, AbstractDict)
            if !is_props_dict(v)
                return false
            end
        end
    end

    return true
end

is_props_dict(d::AbstractDict) = false


function to_props_dict(d::AbstractDict)
    result = Dict{Any,Any}()

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
            to_props_dict(convert(Dict{Any,Any}, v))
        else
            v
        end

        result[k_new] = v_new
    end

    result
end


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
        trim_void!(d)
    end

    PropDict(d)
end


function Base.read(::Type{PropDict}, filenames::Vector{<:AbstractString}; subst_pathvar::Bool = false, subst_env::Bool = false, trim_null::Bool = false)
    p = PropDict()
    for f in filenames
        merge!(p, read(PropDict, f, subst_pathvar = subst_pathvar, subst_env = subst_env, trim_null = false))
    end

    if trim_null
        trim_void!(_dict(p))
    end

    p
end
