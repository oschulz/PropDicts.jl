# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


function contains_vars(s::AbstractString)
    escaped = false
    for c in s
        if c == '\\'
            escaped = !escaped
        else
            if c == '$' && !escaped
                return true
            end
            escaped = false
        end
    end

    return false
end


_isalnum(c::Char) = isletter(c) || isnumeric(c)

_is_var_char(c::Char) = _isalnum(c) || (c == '_')

_subst_error(msg::AbstractString, input::AbstractString) =
    throw(ArgumentError("$msg during variable substitution in string \"$input\""))

function substitute_vars(input::AbstractString, var_values::Dict{String,String} = Dict{String,String}(); use_env::Bool = false, ignore_missing::Bool = false)
    if !contains_vars(input) && !occursin('\\', input)
        return input
    end

    out = IOBuffer()
    from = firstindex(input)
    to = lastindex(input)
    i = from

    while i <= to
        c = input[i]
        j = nextind(input, i)
        if (c == '\\') && (j <= to) && (input[j] == '\\' || input[j] == '$')
            print(out, input[j])
            i = nextind(input, j)
        elseif (c == '$') && (j <= to)
            open_brace = (input[j] == '{' || input[j] == '(') ? input[j] : Char(0)
            close_brace = (open_brace == '{') ? '}' : ')'
            name_from = (open_brace != Char(0)) ? nextind(input, j) : j

            k = name_from
            if open_brace != Char(0)
                while (k <= to) && !(input[k] == '}' || input[k] == ')')
                    ck = input[k]
                    (ck == '{' || ck == '(') && _subst_error("Encountered extra \"$ck\"", input)
                    (ck == '\\') && _subst_error("Encountered illegal character \"\\\" in variable name", input)
                    k = nextind(input, k)
                end
                (k > to) && _subst_error("Missing \"$close_brace\" for \"\$$open_brace\"", input)
                (input[k] != close_brace) && _subst_error("Encountered closing \"$(input[k])\" for open \"$open_brace\"", input)
                (k == name_from) && _subst_error("Encountered illegal \"\$$open_brace$close_brace\"", input)
                var_name = input[name_from:prevind(input, k)]
                expr_to = k
                i_next = nextind(input, k)
            else
                while (k <= to) && _is_var_char(input[k])
                    k = nextind(input, k)
                end
                if k == name_from
                    print(out, '$', input[k])
                    i = nextind(input, k)
                    continue
                end
                var_name = input[name_from:prevind(input, k)]
                expr_to = prevind(input, k)
                i_next = k
            end

            isnumeric(first(var_name)) && _subst_error("Illegal variable name, starting with a digit,", input)

            subst_value = if haskey(var_values, var_name)
                var_values[var_name]
            elseif use_env && haskey(ENV, var_name)
                ENV[var_name]
            elseif ignore_missing
                input[i:expr_to]
            else
                _subst_error("Unknown variable \"$var_name\"", input)
            end

            if (i == from) && (i_next > to)
                return subst_value
            end
            print(out, subst_value)
            i = i_next
        else
            print(out, c)
            i = j
        end
    end

    return String(take!(out))
end


_needs_substitution(s::AbstractString) = contains_vars(s) || occursin('\\', s)


function substitute_vars!(
    d::AbstractDict, var_values::Dict{String,String} = Dict{String,String}();
    use_env::Bool = false, ignore_missing::Bool = false, recursive::Bool = true
)
    for (k, v) in d
        if isa(v, Union{AbstractDict,AbstractArray})
            if recursive
                substitute_vars!(v, var_values, use_env = use_env, ignore_missing = ignore_missing, recursive = recursive)
            end
        elseif isa(v, AbstractString) && _needs_substitution(v)
            d[k] = substitute_vars(v, var_values, use_env = use_env, ignore_missing = ignore_missing)
        end
    end
    d
end

function substitute_vars!(
    A::AbstractArray, var_values::Dict{String,String} = Dict{String,String}();
    use_env::Bool = false, ignore_missing::Bool = false, recursive::Bool = true
)
    for i in eachindex(A)
        v = A[i]
        if isa(v, Union{AbstractDict,AbstractArray})
            if recursive
                substitute_vars!(v, var_values, use_env = use_env, ignore_missing = ignore_missing, recursive = recursive)
            end
        elseif isa(v, AbstractString) && _needs_substitution(v)
            A[i] = substitute_vars(v, var_values, use_env = use_env, ignore_missing = ignore_missing)
        end
    end
    A
end
