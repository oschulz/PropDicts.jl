# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


function deepmerge!(d::Associative, others::Associative...)
    for other in others
        for (k, v) in other
            if haskey(d, k)
                v_curr = d[k]
                if isa(v_curr, Associative)
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


deepmerge(d::Associative, others::Associative...) =
    deepmerge!(Base.emptymergedict(d, others...), d, others...)



function trim_void!(d::Associative; recursive::Bool = true)
    for (k, v) in d
        if isa(v, Associative)
            if recursive
                trim_void!(v, recursive = recursive)
            end
        elseif typeof(v) == Void
            delete!(d, k)
        end
    end
    d
end


trim_void(d::Associative; recursive::Bool = true) =
    trim_void!(deepcopy(d), recursive = recursive)
