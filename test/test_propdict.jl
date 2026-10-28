# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

using PropDicts: deepmerge, deepmerge!

using Functors: fmap, functor

@testset "propdict construction" begin
    # Nested dicts are always PropDicts, wrapping a compatible dict does not copy:
    dc = Dict{Union{Symbol,Int},Any}(:a => Dict{Union{Symbol,Int},Any}(:b => 1))
    @test PropDict(dc).a isa PropDict
    dcc = Dict{Union{Symbol,Int},Any}(:a => PropDict(:b => 1))
    @test PropDicts._dict(PropDict(dcc)) === dcc
end

@testset "propdict" begin
    da = Dict("foo" => 11, "bar" => Dict("baz" => 42), "44" => "abc")
    @test @inferred(PropDict(da)) isa PropDict

    pa = PropDict(da)
    @test parent(pa) === PropDicts._dict(pa)

    @test @inferred(Dict(pa)) === parent(pa)
    @test @inferred(Dict{Union{Symbol,Int},Any}(pa)) === parent(pa)
    @test @inferred(convert(Dict, pa)) === parent(pa)
    @test @inferred(convert(Dict{Union{Symbol,Int},Any}, pa)) === parent(pa)

    @test @inferred(empty(pa)) isa PropDict
    @test @inferred(isempty(empty(pa)))

    @test convert(Dict, pa) === PropDicts._dict(pa)
    @test convert(Dict{Union{Symbol,Int}}, pa) === PropDicts._dict(pa)
    @test convert(Dict{Union{Symbol,Int},Any}, pa) === PropDicts._dict(pa)

    @test sort(@inferred propertynames(pa)) == [:bar, :foo]
    @test sort(propertynames(pa, true)) == [:_internal_dict, :bar, :foo]

    pb = PropDict(Dict("foo" => 13, :bar => PropDict(:baz => raw"$somevar")))

    @test functor(pb)[1] isa Dict
    @test all(x -> x isa AbstractFloat, values(fmap(float, PropDict(:x => PropDict(:a => 1, :b => 2))).x))

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

    px = PropDict("foo" => 11, "bar" => PropDict("baz" => PropDict("a" => 7, "b" => 9)), "44" => "abc")
    py = PropDict("bar" => PropDict("baz" => nothing, "baz2" => 5))
    pz = @inferred(merge!(px, py))
    @test pz === px
    @test pz == Dict(:foo => 11, :bar => Dict(:baz => nothing, :baz2 => 5), 44 => "abc")

    @test PropDicts.contains_vars(raw"fo\\$o") == true
    @test PropDicts.substitute_vars(raw"foo $bar ${baz} y", ignore_missing = true) == raw"foo $bar ${baz} y"
    PropDicts.substitute_vars(raw"foo $bar baz", Dict("bar" => "xyz"))
    s = "xyz"
    PropDicts.substitute_vars(raw"foo$(bar)x$HOME,baz", Dict("bar" => "xyz"), use_env = true)

    PropDicts.substitute_vars!(parent(pc), Dict("somevar" => "xyz"))

    xa = deepcopy(pa)
    @test xa.a.b isa PropDicts.MissingProperty
    @test (xa.a.b[33].c = 42) == 42
    @test xa.a.b[33].c == 42
    
    pd = PropDict(:a => 42)
    @test get(pd, :a, 7) == 42
    @test pd.b isa PropDicts.MissingProperty
    @test get(pd, :b, 7) == 7
    @test pd.b isa PropDicts.MissingProperty
    @test get!(pd, :b, 9) == 9
    @test !(pd.b isa PropDicts.MissingProperty)
    @test pd.b == 9

    @test pd.c isa PropDicts.MissingProperty
    @test pd.c.d isa PropDicts.MissingProperty
    @test get(pd.c, :d, 5) == 5
    @test pd.c isa PropDicts.MissingProperty
end

@testset "dict interface" begin
    p = PropDict(:a => 1, :b => PropDict(:c => 2), 44 => "abc")

    p.x = 5
    @test p.x == 5

    @test get(() -> 7, p, :nope) == 7
    @test get(() -> 7, p, :a) == 1
    r = get!(() -> Dict("y" => 2), p, :g)
    @test r isa PropDict && p.g.y == 2
    @test get!(p, :h, Dict("z" => 3)) isa PropDict
    @test p.h.z == 3

    @test getkey(p, :nope, nothing) === nothing

    @test pop!(p, :x) == 5
    @test pop!(p, :x, :dflt) == :dflt
    @test_throws KeyError pop!(p, :x)
    @test delete!(p, 44) === p
    @test !haskey(p, 44)

    q = copy(p)
    @test q isa PropDict && q == p
    @test PropDicts._dict(q) !== PropDicts._dict(p)
    @test sizehint!(q, 100) === q
    @test empty!(q) === q && isempty(q)
    @test !isempty(p)
end
