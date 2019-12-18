# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

import Test
Test.@testset "Package PropDicts" begin

include("test_varsubst.jl")
include("test_propdict.jl")

end # testset
