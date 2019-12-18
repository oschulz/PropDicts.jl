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


function trim_void!(d::AbstractDict; recursive::Bool = true)
    for (k, v) in d
        if isa(v, AbstractDict)
            if recursive
                trim_void!(v, recursive = recursive)
            end
        elseif typeof(v) == Nothing
            delete!(d, k)
        end
    end
    d
end


trim_void(d::AbstractDict; recursive::Bool = true) =
    trim_void!(deepcopy(d), recursive = recursive)
