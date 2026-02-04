# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

module PropDictsJSONExt

using PropDicts
import JSON

PropDicts._read_from(::Val{:JSON}, filename::String) = JSON.parsefile(filename)

function PropDicts._write_to(::Val{:JSON}, io::IO, p::PropDict, multiline::Bool, indent::Int)
    indent_value = indent < 0 ? 4 : indent
    if multiline
        JSON.print(io, p, indent_value)
    else
        JSON.print(io, p)
    end
end

end # module PropDictsJSONExt
