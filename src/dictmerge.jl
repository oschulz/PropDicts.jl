# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


"""
    deepmerge!(d::AbstractDict, others::AbstractDict...)

Merge `others` into `d` recursively: entries whose values are dicts on
both sides are deep-merged in place, all other entries are overwritten.
"""
function deepmerge!(d::AbstractDict, others::AbstractDict...)
    for other in others
        for (k, v) in other
            if haskey(d, k) && isa(d[k], AbstractDict) && isa(v, AbstractDict)
                deepmerge!(d[k], v)
            else
                d[k] = v
            end
        end
    end
    d
end


_promoted_keytype(K::Type) = K
_promoted_keytype(K::Type, d::AbstractDict, others::AbstractDict...) =
    _promoted_keytype(promote_type(K, keytype(d)), others...)

_promoted_valtype(V::Type) = V
_promoted_valtype(V::Type, d::AbstractDict, others::AbstractDict...) =
    _promoted_valtype(promote_type(V, valtype(d)), others...)


function _deepmerge_into!(result::AbstractDict, others::AbstractDict...)
    for other in others
        for (k, v) in other
            if haskey(result, k) && isa(result[k], AbstractDict) && isa(v, AbstractDict)
                result[k] = deepmerge(result[k], v)
            else
                result[k] = v
            end
        end
    end
    result
end

"""
    deepmerge(d::AbstractDict, others::AbstractDict...)

Non-mutating version of [`deepmerge!`](@ref): returns a new dict, the
inputs are left unchanged.
"""
function deepmerge(d::AbstractDict, others::AbstractDict...)
    K = _promoted_keytype(keytype(d), others...)
    V = _promoted_valtype(valtype(d), others...)
    _deepmerge_into!(empty(d, K, V), d, others...)
end



"""
    trim_null!(d::AbstractDict; recursive::Bool = true)

Remove entries with a value of `nothing` from `d`.

Operates recursively on nested dicts and arrays if `recursive == true`.
Dicts inside arrays are trimmed, but array elements themselves are never
removed since they are positional.
"""
function trim_null! end


function trim_null!(d::AbstractDict; recursive::Bool = true)
    for (k, v) in d
        if isa(v, Union{AbstractDict,AbstractArray})
            if recursive
                trim_null!(v, recursive = recursive)
            end
        elseif v === nothing
            delete!(d, k)
        end
    end
    d
end

function trim_null!(A::AbstractArray; recursive::Bool = true)
    if recursive
        for v in A
            if isa(v, Union{AbstractDict,AbstractArray})
                trim_null!(v, recursive = recursive)
            end
        end
    end
    A
end


"""
    trim_null(d::AbstractDict; recursive::Bool = true)

Non-mutating version of [`trim_null!`](@ref), operates on a deep copy of `d`.
"""
trim_null(d::AbstractDict; recursive::Bool = true) =
    trim_null!(deepcopy(d), recursive = recursive)
