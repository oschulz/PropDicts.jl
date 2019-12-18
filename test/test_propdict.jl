# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

@testset "propdict" begin
    pa = PropDict(Dict("foo" => 11, "bar" => Dict("baz" => 42), "44" => "abc"))
    pb = PropDict(Dict("foo" => 13, :bar => Dict(:baz => raw"$somevar")))

    @test pa == deepcopy(pa)
    @test pa != pb

    @test @inferred(merge(pa, pb)) isa PropDict
    pc = merge(pa, pb)
    @test pc.dict[:foo] == 13
    @test pc.dict[:bar] == Dict(:baz => raw"$somevar")
    @test pc.dict[44] == "abc"

    @test PropDicts.contains_vars(raw"fo\\$o") == true
    @test PropDicts.substitute_vars(raw"foo $bar ${baz} y", ignore_missing = true) == raw"foo $bar ${baz} y"
    PropDicts.substitute_vars(raw"foo $bar baz", Dict("bar" => "xyz"))
    s = "xyz"
    PropDicts.substitute_vars(raw"foo$(bar)x$HOME,baz", Dict("bar" => "xyz"), use_env = true)

    PropDicts.substitute_vars!(pc.dict, Dict("somevar" => "xyz"))
end
