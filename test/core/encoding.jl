using Test
using CausalityTools
using Random
rng = Xoshiro(1234)

x = StateSpaceSet(rand(rng, 50, 3))
y = StateSpaceSet(rand(rng, 50, 3))
z = StateSpaceSet(rand(rng, 50, 2))
w = rand(rng, ['a', 'b'], 50)
o2 = OrdinalPatternEncoding(2)
o3 = OrdinalPatternEncoding(3)
ow = UniqueElementsEncoding(w)

# Using a single encoding should apply the encoding to all input datasets.
@test encode(PerPointEncoding(o3), x) isa Vector{<:Integer}
@test encode(PerPointEncoding(o3), x, x) isa NTuple{2, Vector{<:Integer}}

# Using multiple encodings, the number of input encodings must match the number of
# input datasets.
@test encode(PerPointEncoding(o3, ow), x, w) isa NTuple{2, Vector{<:Integer}}
@test encode(PerPointEncoding(o3, o3), x, x) isa NTuple{2, Vector{<:Integer}}
@test encode(PerPointEncoding(o2, o3), z, x) isa NTuple{2, Vector{<:Integer}}
@test encode(PerPointEncoding(o2, o3, o3), z, x, y) isa NTuple{3, Vector{<:Integer}}

# Length-2 encoding won't work on state vectors of length 3
@test_throws ArgumentError encode(PerPointEncoding(o2), x)

# When multiple encodings are provided, then the length of the encoding must match
# the length of the points. Here, we accidentally mixed the order of the encodings.
@test_throws ArgumentError encode(PerPointEncoding(o3, o2, o3), z, x, y)

#----------------------------------------------------------------
# Per variable/column encoding
#----------------------------------------------------------------

# Single variables
x = rand(rng, 100)
o = ValueBinning(3)
@test encode(PerVariableEncoding(o), x) isa Vector{<:Integer}
@test encode(PerVariableEncoding(o), (x, )) isa NTuple{1, Vector{<:Integer}}

# Multiple variables
y = StateSpaceSet(randn(rng, 100, 2))
o = ValueBinning(3)
@test encode(PerVariableEncoding(o), y) isa NTuple{2, Vector{<:Integer}}
@test encode(PerVariableEncoding(o), (y[:, 1], y[:, 2])) isa NTuple{2, Vector{<:Integer}}
@test encode(PerVariableEncoding(o), (y[:, 1], y[:, 2])) ==
    encode(PerVariableEncoding(o), y)
