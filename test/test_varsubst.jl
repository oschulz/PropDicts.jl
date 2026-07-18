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

    # Non-ASCII strings:
    @test PropDicts.substitute_vars("ä\$x", Dict("x" => "y")) == "äy"
    @test PropDicts.substitute_vars("日本\${x}語", Dict("x" => "y")) == "日本y語"
    @test PropDicts.substitute_vars("ä\${x}ö", Dict("x" => "y")) == "äyö"
    @test PropDicts.substitute_vars("ö\$vär", Dict("vär" => "y")) == "öy"
    @test PropDicts.substitute_vars("ö\${vär}", Dict("vär" => "y")) == "öy"
    @test PropDicts.substitute_vars("ä\$x", Dict("x" => "ü")) == "äü"
    @test PropDicts.substitute_vars("\$x", Dict("x" => "ü")) == "ü"

    # SubString and other AbstractString input and values:
    @test PropDicts.contains_vars(SubString("abc \$x", 5)) == true
    @test PropDicts.substitute_vars(SubString("abc \$x def", 5), Dict("x" => "1")) == "1 def"

    # Corner cases:
    @test PropDicts.substitute_vars("a\$x", Dict("x" => "y")) == "ay"
    @test PropDicts.substitute_vars("\$x\$y", Dict("x" => "1", "y" => "2")) == "12"
    @test PropDicts.substitute_vars("\$", Dict{String,String}()) == "\$"
    @test PropDicts.substitute_vars("a\$", Dict{String,String}()) == "a\$"
    @test PropDicts.substitute_vars("a\$ b", Dict{String,String}()) == "a\$ b"
    @test PropDicts.substitute_vars("a\$\$b", Dict{String,String}()) == "a\$\$b"
    @test PropDicts.substitute_vars(raw"a\$x b", Dict{String,String}()) == raw"a\$x b"
    @test PropDicts.substitute_vars("\${x}", Dict("x" => "y")) == "y"
    @test PropDicts.substitute_vars("pre\${x}", Dict("x" => "y")) == "prey"
    @test_throws ArgumentError PropDicts.substitute_vars("\${}", Dict{String,String}())

    # Escaped dollar in a string that also contains variables:
    @test PropDicts.substitute_vars(raw"\$a $x b", Dict("x" => "1")) == raw"\$a 1 b"

    # In-place substitution in dicts and arrays:
    d = Dict("a" => raw"$x", "b" => Dict("c" => raw"${x}y"), "d" => [raw"$x", 1, [raw"$x"], Dict("e" => raw"$x")])
    PropDicts.substitute_vars!(d, Dict("x" => "1"))
    @test d == Dict("a" => "1", "b" => Dict("c" => "1y"), "d" => ["1", 1, ["1"], Dict("e" => "1")])

    d2 = Dict("a" => raw"$x", "b" => Dict("c" => raw"$x"))
    PropDicts.substitute_vars!(d2, Dict("x" => "1"), recursive = false)
    @test d2 == Dict("a" => "1", "b" => Dict("c" => raw"$x"))

    A = Any[raw"$x", Any[raw"$x"]]
    PropDicts.substitute_vars!(A, Dict("x" => "1"), recursive = false)
    @test A == Any["1", Any[raw"$x"]]
end
