# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

using PropDicts: deepmerge, deepmerge!, trim_null, trim_null!

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

        da = Dict(:a => Dict(:b => 1), :c => 2)
        db = Dict(:a => Dict(:d => 3.5))
        dm = deepmerge(da, db)
        @test dm == Dict(:a => Dict(:b => 1, :d => 3.5), :c => 2)
        @test keytype(dm) == Symbol && valtype(dm) == Any
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
    end

    @testset "trim_null" begin
        d = PropDict(:a => PropDict(:b => nothing, :c => 1), :d => nothing, :e => 2)
        d_orig = deepcopy(d)

        t = trim_null(d)
        @test t == PropDict(:a => PropDict(:c => 1), :e => 2)
        @test d == d_orig

        t_shallow = trim_null(d, recursive = false)
        @test t_shallow == PropDict(:a => PropDict(:b => nothing, :c => 1), :e => 2)

        @test trim_null!(d) === d
        @test d == PropDict(:a => PropDict(:c => 1), :e => 2)
    end
end
