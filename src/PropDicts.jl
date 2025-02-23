# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

__precompile__(true)

module PropDicts

import JSON
import YAML

include("dictmerge.jl")
include("varsubst.jl")
include("propdict.jl")

end # module
