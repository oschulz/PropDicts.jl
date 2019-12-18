# PropDicts.jl

PropDicts implements dictionaries that handle hierarchical property/value
data.

[`PropDict`](@ref) is a special kind of `AbstractDict` that supports deep merging.
A typicial use case is cascading-configuration: A basic configuration
can be modified by additional configuration `PropDict`s that only replace,
amend or remove specific parts of it.

In addition, there is support for variable substitution, to make it possible
to refer to environment variables and application-specific variables in
configuration data.
