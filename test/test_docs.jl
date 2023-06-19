# This file is a part of PropDicts.jl, licensed under the MIT License (MIT).

using Test
using PropDicts
import Documenter

Documenter.DocMeta.setdocmeta!(
    PropDicts,
    :DocTestSetup,
    :(using PropDicts);
    recursive=true,
)
Documenter.doctest(PropDicts)
