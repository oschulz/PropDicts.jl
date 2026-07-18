# PropDicts.jl

PropDicts implements dictionaries that handle hierarchical property/value
data.

[`PropDict`](@ref) is a special kind of `AbstractDict` that supports deep merging.
A typical use case is cascading-configuration: A basic configuration
can be modified by additional configuration `PropDict`s that only replace,
amend or remove specific parts of it.

`PropDict`s can be constructed from dicts, key-value pairs and keyword
arguments, as well as from named-tuple syntax via [`@propdict`](@ref):

```julia
using PropDicts

p1 = PropDict(:a => PropDict(:b => 7, :c => 5), :e => "foo")
p2 = PropDict(a = PropDict(b = 7, c = 5), e = "foo")
p3 = @propdict (a = (b = 7, c = 5), e = "foo")
p1 == p2 == p3
```

In addition, there is support for variable substitution, to make it possible
to refer to environment variables and application-specific variables in
configuration data.

Reading/writing from/to JSON and YAML is supported as well.
