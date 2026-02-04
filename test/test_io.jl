# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using PropDicts
using Test

import JSON
import YAML

@testset "JSON and YAML I/O" begin
    # Create a test PropDict
    p = PropDict(
        :name => "test",
        :value => 42,
        :nested => PropDict(
            :a => 1,
            :b => "hello"
        ),
        :list => [1, 2, 3]
    )

    @testset "JSON I/O" begin
        # Test writing to IO
        io = IOBuffer()
        writeprops(io, p; format = :JSON)
        json_str = String(take!(io))
        @test !isempty(json_str)
        @test occursin("\"name\"", json_str)
        @test occursin("\"test\"", json_str)

        # Test writing with multiline=false
        io = IOBuffer()
        writeprops(io, p; format = :JSON, multiline = false)
        json_str_compact = String(take!(io))
        @test length(json_str_compact) < length(json_str)

        # Test writing and reading from file
        mktempdir() do tmpdir
            jsonfile = joinpath(tmpdir, "test.json")
            writeprops(jsonfile, p)
            @test isfile(jsonfile)

            # Read back
            p_read = readprops(jsonfile)
            @test p_read isa PropDict
            @test p_read[:name] == "test"
            @test p_read[:value] == 42
            @test p_read[:nested][:a] == 1
            @test p_read[:nested][:b] == "hello"
        end

        # Test variable substitution in JSON
        mktempdir() do tmpdir
            jsonfile = joinpath(tmpdir, "test_subst.json")
            open(jsonfile, "w") do io
                write(io, """{"path": "\$_/data", "home": "\$HOME"}""")
            end

            p_subst = readprops(jsonfile; subst_pathvar = true, subst_env = true)
            @test normpath(p_subst[:path]) == normpath(joinpath(tmpdir, "data"))
            @test p_subst[:home] == ENV["HOME"]
        end
    end

    @testset "YAML I/O" begin
        # Test writing to IO
        io = IOBuffer()
        writeprops(io, p; format = :YAML)
        yaml_str = String(take!(io))
        @test !isempty(yaml_str)
        @test occursin("name:", yaml_str)
        @test occursin("test", yaml_str)

        # Test that multiline=false throws
        io = IOBuffer()
        @test_throws ArgumentError writeprops(io, p; format = :YAML, multiline = false)

        # Test that non-default indent throws
        io = IOBuffer()
        @test_throws ArgumentError writeprops(io, p; format = :YAML, indent = 4)

        # Test writing and reading from file
        mktempdir() do tmpdir
            yamlfile = joinpath(tmpdir, "test.yaml")
            writeprops(yamlfile, p)
            @test isfile(yamlfile)

            # Read back
            p_read = readprops(yamlfile)
            @test p_read isa PropDict
            @test p_read[:name] == "test"
            @test p_read[:value] == 42
            @test p_read[:nested][:a] == 1
            @test p_read[:nested][:b] == "hello"

            # Test .yml extension
            ymlfile = joinpath(tmpdir, "test.yml")
            writeprops(ymlfile, p)
            @test isfile(ymlfile)
            p_read_yml = readprops(ymlfile)
            @test p_read_yml[:name] == "test"
        end

        # Test variable substitution in YAML
        mktempdir() do tmpdir
            yamlfile = joinpath(tmpdir, "test_subst.yaml")
            open(yamlfile, "w") do io
                write(io, "path: \"\$_/data\"\nhome: \"\$HOME\"\n")
            end

            p_subst = readprops(yamlfile; subst_pathvar = true, subst_env = true)
            @test normpath(p_subst[:path]) == normpath(joinpath(tmpdir, "data"))
            @test p_subst[:home] == ENV["HOME"]
        end
    end

    @testset "Multiple file merge" begin
        mktempdir() do tmpdir
            file1 = joinpath(tmpdir, "base.json")
            file2 = joinpath(tmpdir, "override.json")

            open(file1, "w") do io
                write(io, """{"a": 1, "b": {"c": 2, "d": 3}}""")
            end
            open(file2, "w") do io
                write(io, """{"a": 10, "b": {"c": 20}}""")
            end

            p_merged = readprops([file1, file2])
            @test p_merged[:a] == 10
            @test p_merged[:b][:c] == 20
            @test p_merged[:b][:d] == 3
        end
    end

    @testset "Unsupported format" begin
        mktempdir() do tmpdir
            txtfile = joinpath(tmpdir, "test.txt")
            touch(txtfile)
            @test_throws ArgumentError readprops(txtfile)
        end
    end

    @testset "trim_null in readprops" begin
        mktempdir() do tmpdir
            jsonfile = joinpath(tmpdir, "test_null.json")
            open(jsonfile, "w") do io
                write(io, """{"a": 1, "b": null, "c": {"d": null, "e": 2}}""")
            end

            # With trim_null (default)
            p_trimmed = readprops(jsonfile)
            @test !haskey(p_trimmed, :b)
            @test !haskey(p_trimmed[:c], :d)
            @test p_trimmed[:c][:e] == 2

            # Without trim_null
            p_with_null = readprops(jsonfile; trim_null = false)
            @test haskey(p_with_null, :b)
            @test p_with_null[:b] === nothing
        end
    end
end
