# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

module PropDictsFunctorsExt

using PropDicts
using PropDicts: _dict
import Functors

function Functors.functor(::Type{<:PropDict}, p)
    content, f_rec = Functors.functor(Dict, _dict(p))
    return content, x -> PropDict(f_rec(x))
end

end # module PropDictsFunctorsExt
