# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

using PropDicts: deepmerge, deepmerge!

@testset "dictmerge" begin
    @testset "deepmerge" begin
        x = PropDict(:a => PropDict(:b => 7, :c => 5, :d => 2), :e => "foo")
        y = PropDict(:a => PropDict(:c => 42, :d => nothing), :f => "bar")
        x_orig = deepcopy(x)
        y_orig = deepcopy(y)

        z = @inferred merge(x, y)
        @test z isa PropDict
        @test z == PropDict(
            :a => PropDict(:b => 7, :c => 42, :d => nothing),
            :e => "foo", :f => "bar"
        )
        @test x == x_orig
        @test y == y_orig

        @test merge(x) == x
        @test merge(x) !== x

        # Dict values of the inputs are copied into the result:
        g = PropDict(:g => PropDict(:h => 1))
        z2 = merge(x, g)
        z2.a.b = 0
        z2.g.h = 0
        @test x == x_orig
        @test g.g.h == 1

        z3 = merge(x, y, PropDict(:a => PropDict(:b => 1), :e => nothing))
        @test z3 == PropDict(
            :a => PropDict(:b => 1, :c => 42, :d => nothing),
            :e => nothing, :f => "bar"
        )
        @test x == x_orig

        # scalar/dict conflicts overwrite in either direction:
        @test merge(PropDict(:a => 1), PropDict(:a => PropDict(:b => 2))) ==
            PropDict(:a => PropDict(:b => 2))
        @test merge(PropDict(:a => PropDict(:b => 2)), PropDict(:a => 1)) ==
            PropDict(:a => 1)
        @test merge(PropDict(:a => nothing), PropDict(:a => PropDict(:b => 2))) ==
            PropDict(:a => PropDict(:b => 2))

        # merge with other dicts is the shallow Base.merge:
        p = PropDict(:a => PropDict(:x => 1, :y => 2))
        pm = merge(p, Dict(:a => Dict(:x => 9)))
        @test pm isa Dict && pm[:a] == Dict(:x => 9)
        @test p == PropDict(:a => PropDict(:x => 1, :y => 2))
        @test deepmerge(p, Dict("a" => Dict("x" => 9))) == PropDict(:a => PropDict(:x => 9, :y => 2))

        # Immutable dicts are shared, PropDicts convert them:
        im = Base.ImmutableDict(:x => 1)
        @test deepmerge(Dict(:a => im))[:a] === im
        @test deepmerge(Dict{Symbol,Any}(:a => Base.ImmutableDict(im, :x => 2)))[:a][:x] == 2
        @test deepmerge(PropDict(), Dict(:a => im)).a == PropDict(:x => 1)

        da = Dict(:a => Dict(:b => 1), :c => 2)
        db = Dict(:a => Dict(:d => 3))
        dm = deepmerge(da, db)
        @test dm == Dict(:a => Dict(:b => 1, :d => 3), :c => 2)
        @test keytype(dm) == Symbol && valtype(dm) == Any
        deepmerge(da, Dict(:c => 3))[:a][:b] = 0
        @test da == Dict(:a => Dict(:b => 1), :c => 2)

        dp = deepmerge(Dict(:a => 1), Dict(:b => 2.5))
        @test valtype(dp) == Float64
    end

    @testset "deepmerge!" begin
        x = PropDict(:a => PropDict(:b => 7, :c => 5), :e => "foo")
        y = PropDict(:a => PropDict(:c => 42), :f => "bar")
        @test merge!(x, y) === x
        @test x == PropDict(:a => PropDict(:b => 7, :c => 42), :e => "foo", :f => "bar")

        x2 = PropDict(:a => PropDict(:b => 1))
        merge!(x2, PropDict(:a => nothing))
        @test x2 == PropDict(:a => nothing)

        # Dict values of the merged-in dicts are copied into the target:
        default = PropDict(:filter => PropDict(:ft => 0.2))
        t = merge!(PropDict(), default)
        merge!(t, PropDict(:filter => PropDict(:ft => 0.5)))
        @test t.filter.ft == 0.5
        @test default.filter.ft == 0.2

        src = Dict(:a => Dict(:b => 1))
        deepmerge!(Dict{Symbol,Any}(), src)[:a][:b] = 0
        @test src[:a][:b] == 1

        # Nested dicts are merged in place, existing values keep their type:
        big = 2^53 + 1
        dn = deepmerge!(Dict{Symbol,Any}(:a => Dict(:x => big)), Dict(:a => Dict{Symbol,Float64}()))
        @test dn[:a][:x] === big
    end
end
