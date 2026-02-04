# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

module PropDictsYAMLExt

using PropDicts
import YAML

PropDicts._read_from(::Val{:YAML}, filename::String) = YAML.load_file(filename)

function PropDicts._write_to(::Val{:YAML}, io::IO, p::PropDict, multiline::Bool, indent::Int)
    indent_value = indent < 0 ? 2 : indent
    if !multiline
        throw(ArgumentError("YAML can only be written in multiple lines, `multiline = false` is not supported."))
    end
    if indent_value != 2
        throw(ArgumentError("YAML is always indented by 2 spaces, `indent = $indent_value` is not supported."))
    end

    YAML.write(io, p)
    return nothing
end

end # module PropDictsYAMLExt
