# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


function deepmerge!(d::AbstractDict, others::AbstractDict...)
    for other in others
        for (k, v) in other
            if haskey(d, k)
                v_curr = d[k]
                if isa(v_curr, AbstractDict)
                    deepmerge!(v_curr, v)
                else
                    d[k] = v
                end
            else
                d[k] = v
            end
        end
    end
    d
end


function deepmerge(d::AbstractDict, others::AbstractDict...)
    K = Base.promoteK(keytype(d), others...)
    V = Base.promoteV(valtype(d), others...)
    result = Dict{K,V}(d)
    deepmerge!(result, others...)
end



"""
    trim_null!(d::AbstractDict; recursive::Bool = true)

Remove values equal to `nothing` from `d`.

Operates recursively on values in `d` if `recursive == true`.
"""
function trim_null! end


function trim_null!(d::AbstractDict; recursive::Bool = true)
    for (k, v) in d
        if isa(v, AbstractDict)
            if recursive
                trim_null!(v, recursive = recursive)
            end
        elseif typeof(v) == Nothing
            delete!(d, k)
        end
    end
    d
end


trim_null(d::AbstractDict; recursive::Bool = true) =
    trim_null!(deepcopy(d), recursive = recursive)
