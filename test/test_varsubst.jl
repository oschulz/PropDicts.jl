# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

@testset "varsubst" begin
    @test @inferred(PropDicts.contains_vars(raw"fo\\$o")) == true
    @test @inferred(PropDicts.substitute_vars(raw"foo $bar ${baz} y", ignore_missing = true)) == raw"foo $bar ${baz} y"
    @test @inferred(PropDicts.substitute_vars(raw"foo $(bar) baz", Dict("bar" => "xyz"))) == "foo xyz baz"

    @test @inferred(PropDicts.substitute_vars(raw"x${nosuchvar}y", ignore_missing = true)) == raw"x${nosuchvar}y"
    @test @inferred(PropDicts.substitute_vars(raw"x$(nosuchvar)y", ignore_missing = true)) == raw"x$(nosuchvar)y"

    # Unknown variable during variable substitution:
    @test_throws ArgumentError PropDicts.substitute_vars(raw"x${nosuchvar}y")

    # Extra "{" during variable substitution:
    @test_throws ArgumentError PropDicts.substitute_vars(raw"${a{}", ignore_missing = true)

    # Closing ")" for open "{" during variable substitution:
    @test_throws ArgumentError PropDicts.substitute_vars(raw"x${nosuchvar)y", ignore_missing = true)

    # Illegal character "\" in variable name :
    @test_throws ArgumentError PropDicts.substitute_vars(raw"x${no\suchvar}y", ignore_missing = true)

    # Illegal variable name, starting with a digit
    @test_throws ArgumentError PropDicts.substitute_vars(raw"x${1nosuchvar}y", ignore_missing = true)

    # Missing "}" for "${" during variable substitution:
    @test_throws ArgumentError PropDicts.substitute_vars(raw"x${nosuchvary", ignore_missing = true)

    ENV["PROPDICT_TEST_A_"] = "some-var-value"
    @test @inferred(PropDicts.substitute_vars(raw"foo$(bar)x$PROPDICT_TEST_A_,baz", Dict("bar" => "xyz"), use_env = true)) == "fooxyzxsome-var-value,baz"
end
