# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

using PropDicts: deepmerge, deepmerge!

using Functors: fmap, functor

@testset "propdict construction" begin
    @test PropDict() isa PropDict
    @test isempty(PropDict())

    @test PropDict(a = 1, b = PropDict(c = 2)) == PropDict(:a => 1, :b => PropDict(:c => 2))
    @test PropDict(:a => 1; b = 2) == PropDict(:a => 1, :b => 2)
    @test PropDict(a = Dict("x" => 1)).a isa PropDict

    x = 42
    p = @propdict (a = (b = 7, c = 5), e = "foo", f = x)
    @test p == PropDict(:a => PropDict(:b => 7, :c => 5), :e => "foo", :f => 42)
    @test p.a isa PropDict
    @test (@propdict (a = 1)) == PropDict(:a => 1)
    @test (@propdict (a = (b = 1,),)).a.b == 1
    @test (@propdict (; a = 1, b = (; c = 2))).b.c == 2
    @test isempty(@propdict ())
    @test isempty(@propdict (;))
    @test (@propdict (a = x + 1, b = (c = [1, 2, 3],))) ==
        PropDict(:a => 43, :b => PropDict(:c => [1, 2, 3]))
    @test_throws ArgumentError PropDicts._propdict_expr(:([1, 2]))
    @test_throws ArgumentError PropDicts._propdict_expr(:((1, 2)))
    @test_throws ArgumentError PropDicts._propdict_expr(42)

    # Nested dicts are always PropDicts, wrapping a compatible dict does not copy:
    dc = Dict{Union{Symbol,Int},Any}(:a => Dict{Union{Symbol,Int},Any}(:b => 1))
    @test PropDict(dc).a isa PropDict
    dcc = Dict{Union{Symbol,Int},Any}(:a => PropDict(:b => 1))
    @test PropDicts._dict(PropDict(dcc)) === dcc

    # Numeric string keys become Int keys:
    @test collect(keys(PropDict("007" => 1))) == [7]
    @test collect(keys(PropDict("+5" => 1))) == [5]
    @test collect(keys(PropDict("-3" => 1))) == [-3]
    @test collect(keys(PropDict("99999999999999999999" => 1))) == [Symbol("99999999999999999999")]

    @test_throws ArgumentError PropDict(Dict(2.5 => 1))

    # Dicts inside arrays are converted, arrays without dicts are not copied:
    pl = PropDict(:list => [Dict("a" => 1), Dict("b" => 2)])
    @test pl.list isa AbstractVector
    @test all(x -> x isa PropDict, pl.list)
    @test pl.list[1].a == 1
    v_num = [1.0, 2.0, 3.0]
    @test PropDict(:x => v_num).x === v_num
    v_ok = [PropDict(:a => 1)]
    @test PropDict(:x => v_ok).x === v_ok
    @test PropDict(:x => [[Dict("a" => 1)]]).x[1][1] isa PropDict
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
