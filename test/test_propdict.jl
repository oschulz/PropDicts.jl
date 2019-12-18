# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

@testset "propdict" begin
    da = Dict("foo" => 11, "bar" => Dict("baz" => 42), "44" => "abc")
    @test @inferred(PropDict(da)) isa PropDict

    pa = PropDict(da)
    @test parent(pa) === PropDicts._dict(pa)

    @test sort(@inferred propertynames(pa)) == [:bar, :foo]
    @test sort(propertynames(pa, true)) == [:_internal_dict, :bar, :foo]

    pb = PropDict(Dict("foo" => 13, :bar => PropDict(:baz => raw"$somevar")))

    @test pa == deepcopy(pa)
    @test pa != pb

    @test pa.foo == pa[:foo] == 11
    @test pa.bar == pa[:bar] == PropDict(:baz => 42)
    @test pa[44] == "abc"

    @test @inferred(merge(pa, pb)) isa PropDict
    pc = merge(pa, pb)
    @test pc.foo == 13
    @test pc.bar == PropDict(:baz => raw"$somevar")
    @test pc[44] == "abc"

    @test PropDicts.contains_vars(raw"fo\\$o") == true
    @test PropDicts.substitute_vars(raw"foo $bar ${baz} y", ignore_missing = true) == raw"foo $bar ${baz} y"
    PropDicts.substitute_vars(raw"foo $bar baz", Dict("bar" => "xyz"))
    s = "xyz"
    PropDicts.substitute_vars(raw"foo$(bar)x$HOME,baz", Dict("bar" => "xyz"), use_env = true)

    PropDicts.substitute_vars!(parent(pc), Dict("somevar" => "xyz"))
end
