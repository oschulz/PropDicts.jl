# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


_promoted_keytype(K::Type) = K
_promoted_keytype(K::Type, d::AbstractDict, others::AbstractDict...) =
    _promoted_keytype(promote_type(K, keytype(d)), others...)

_promoted_valtype(V::Type) = V
_promoted_valtype(V::Type, d::AbstractDict, others::AbstractDict...) =
    _promoted_valtype(promote_type(V, valtype(d)), others...)


_merged_value(v) = v
_merged_value(v::AbstractDict) = deepmerge(v)
_merged_value(v::Base.ImmutableDict) = v


"""
    deepmerge!(d::AbstractDict, others::AbstractDict...)

Merge `others` into `d` recursively: entries whose values are dicts on
both sides are deep-merged, all other entries are overwritten.

Dict values of `others` are copied. Other values, like arrays and immutable
dicts like `Base.ImmutableDict`, are shared, including any dicts inside them.
"""
function deepmerge!(d::AbstractDict, others::AbstractDict...)
    for other in others
        for (k, v) in other
            if haskey(d, k) && isa(d[k], AbstractDict) && isa(v, AbstractDict)
                deepmerge!(d[k], v)
            else
                d[k] = _merged_value(v)
            end
        end
    end
    d
end


"""
    deepmerge(d::AbstractDict, others::AbstractDict...)

Non-mutating version of [`deepmerge!`](@ref): returns a new dict, the
inputs are left unchanged. As immutable dicts are shared, merging into one
still changes the mutable dicts inside it.
"""
function deepmerge(d::AbstractDict, others::AbstractDict...)
    K = _promoted_keytype(keytype(d), others...)
    V = _promoted_valtype(valtype(d), others...)
    deepmerge!(empty(d, K, V), d, others...)
end



"""
    trim_null!(d::AbstractDict; recursive::Bool = true)
    trim_null!(A::AbstractArray; recursive::Bool = true)

Remove entries with a value of `nothing` from `d`, resp. from the dicts
in `A`.

Operates recursively on nested dicts if `recursive == true`.
"""
function trim_null! end


function trim_null!(d::AbstractDict; recursive::Bool = true)
    for (k, v) in d
        if isa(v, AbstractDict)
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
    for v in A
        if isa(v, AbstractDict)
            trim_null!(v, recursive = recursive)
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
