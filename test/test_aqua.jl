# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

import Test
import Aqua
import PropDicts

Test.@testset "Aqua tests" begin
    Aqua.test_all(
        PropDicts,
        ambiguities = true
    )
end # testset
