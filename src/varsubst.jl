# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).


function contains_vars(s::String)
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

function substitute_vars(input::AbstractString, var_values::Dict{String,String} = Dict{String,String}(); use_env::Bool = false, ignore_missing::Bool = false)
    if !contains_vars(input)
        return input
    end

    out = IOBuffer()
    idxs = eachindex(input)
    from = first(idxs)
    to = last(idxs)

    npos = from - 1
    no_brace = Char(0)

    open_brache_chars = ('{', '(')
    close_brache_chars = ('}', ')')

    escaped = false
    var_from = npos;
    var_until = npos;
    open_brace = no_brace
    close_brace = no_brace
    pos = from;

    while pos <= to
        c = input[pos];
        if (var_from == npos)
            if c == '\\'
                escaped = !escaped
                print(out, c)
            else
                if ((c == '$') && !escaped && (pos < to))
                    var_from = pos + 1;
                else
                    print(out, c)
                end
                escaped = false
            end
            pos += 1
        else
            if c in open_brache_chars
                if (pos == var_from)
                    var_from = pos + 1
                    open_brace = c
                    close_brace = close_brache_chars[something(findfirst(isequal(open_brace), open_brache_chars), 0)]
                else
                    throw(ArgumentError("Encountered extra \"$c\" during variable substitution in string \"$input\""))
                end
            else
                if !all(_isalnum, c) && (c != '_')
                    if open_brace != no_brace
                        if c in close_brache_chars
                            if c == close_brace
                                var_until = pos
                                pos += 1
                            else
                                throw(ArgumentError("Encountered closing \"$c\" for open \"$open_brace\" during variable substitution in string \"$input\""))
                            end
                        elseif (c == '\\')
                            throw(ArgumentError("Encountered illegal character \"\\\" in variable name during variable substitution in string \"$input\""))
                        end
                    else
                        var_until = pos;
                    end
                elseif isdigit(c) && (pos == var_from)
                    throw(ArgumentError("Illegal variable name, starting with a digit, during variable substitution in string \"$input\""))
                end
            end

            if ( (var_until == npos) && (pos + 1 > to) )
                if open_brace != no_brace
                    throw(ArgumentError("Missing \"$close_brace\" for \"\$$open_brace\" during variable substitution in string \"$input\""))
                else
                    pos += 1
                    var_until = pos
                end
            end

            if (var_until != npos)
                if (var_until > var_from)
                    var_name = input[var_from : var_until - 1];

                    var_expr_from, var_expr_to = (open_brace != no_brace) ? (var_from - 2, var_until) : (var_from - 1, var_until - 1)

                    subst_value = if haskey(var_values, var_name)
                        var_values[var_name]
                    elseif use_env && haskey(ENV, var_name)
                        ENV[var_name]
                    elseif ignore_missing
                        input[var_expr_from:var_expr_to]
                    else
                        throw(ArgumentError("Unknown variable \"$var_name\" during variable substitution in string \"$input\""))
                    end

                    if ((var_expr_from == from) && (var_expr_to == to))
                        return subst_value;
                    else
                        print(out, subst_value);
                    end
                else
                    if open_brace != no_brace
                        throw(ArgumentError("Encountered illegal \"\$$open_brace$close_brace\" during variable substitution in string \"$input\""))
                    else
                        print(out, input[pos-1], input[pos])
                        pos += 1
                    end
                end
                var_from = npos
                var_until = npos
                open_brace = no_brace
            else
                pos += 1
            end
        end
    end

    return String(take!(out))
end


function substitute_vars!(
    d::AbstractDict, var_values::Dict{String,String} = Dict{String,String}();
    use_env::Bool = false, ignore_missing::Bool = false, recursive::Bool = true
)
    for (k, v) in d
        if isa(v, AbstractDict)
            if recursive
                substitute_vars!(v, var_values, use_env = use_env, ignore_missing = ignore_missing, recursive = recursive)
            end
        elseif isa(v, AbstractString) && contains_vars(v)
            d[k] = substitute_vars(v, var_values, use_env = use_env, ignore_missing = ignore_missing)
        end
    end
    d
end
