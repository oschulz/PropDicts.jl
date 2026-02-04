# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

import Test

Test.@testset "Package PropDicts" begin
    include("test_aqua.jl")
    include("test_varsubst.jl")
    include("test_propdict.jl")
    include("test_io.jl")
    include("test_docs.jl")
    isempty(Test.detect_ambiguities(PropDicts))
end # testset
