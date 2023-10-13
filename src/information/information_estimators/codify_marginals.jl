using ComplexityMeasures

"""
    codified_marginals(o::OutcomeSpace, x::VectorOrStateSpaceSet...)

Encode/discretize each input vector `xᵢ ∈ x` according to a procedure determined by `o`.
Any `xᵢ ∈ X` that are multidimensional ([`StateSpaceSet`](@ref)s) will be encoded column-wise,
i.e. each column of `xᵢ` is treated as a timeseries and is encoded separately.

This is useful for computing any discrete information theoretic quantity.

## Supported estimators

- [`ValueBinning`](@ref). Bin visitation frequencies are counted in the joint space `XY`,
    then marginal visitations are obtained from the joint bin visits.
    This behaviour is the same for both [`FixedRectangularBinning`](@ref) and
    [`RectangularBinning`](@ref) (which adapts the grid to the data).
    When using [`FixedRectangularBinning`](@ref), the range along the first dimension
    is used as a template for all other dimensions.
- [`OrdinalPatterns`](@ref). Each timeseries is separately [`encode`](@ref)d according
    to its ordinal pattern.
- [`Dispersion`](@ref). Each timeseries is separately [`encode`](@ref)d according to its
    dispersion pattern.

Many more implementations are possible. Each new implementation gives one new
way of estimating the [`ContingencyMatrix`](@ref)
"""
function codified_marginals end

function codified_marginals(est, x::VectorOrStateSpaceSet...)
    return codify_marginal.(Ref(est), x)
end

function codify_marginal(est, x::AbstractStateSpaceSet)
    return StateSpaceSet(codify_marginal.(Ref(est), columns(x))...)
end

function codify_marginal(o::UniqueElements, x::AbstractVector)
    return x
end

function codify_marginal(o::OrdinalPatterns{m}, x::AbstractVector) where {m}
    return codify(o, x)
end

function codify_marginal(o::Dispersion, x::AbstractVector)
    return codify(o, x)
end

function codify_marginal(
        o::ValueBinning{<:FixedRectangularBinning{D}},
        x::AbstractVector) where D
    range = first(o.binning.ranges)
    ϵmin = minimum(range)
    ϵmax = maximum(range)
    N = length(range)
    encoder = RectangularBinEncoding(FixedRectangularBinning(ϵmin, ϵmax, N, 1))
    return encode.(Ref(encoder), x)
end

# Special treatment for RectangularBinning. We create the joint embedding, then
# extract marginals from that. This could probably be faster,
# but it *works*. I'd rather things be a bit slower than having marginals
# that are not derived from the same joint distribution, which would hugely increase
# bias, because we're not guaranteed cancellation between entropy terms
# in higher-level methods.
function codified_marginals(o::ValueBinning{<:RectangularBinning}, x::VectorOrStateSpaceSet...)
    # TODO: The following line can be faster by explicitly writing out loops that create the 
    # joint embedding vectors.
    X = StateSpaceSet(StateSpaceSet.(x)...)
    encoder = RectangularBinEncoding(o.binning, X)

    bins = [vec(encode_as_tuple(encoder, pt))' for pt in X]
    joint_bins = reduce(vcat, bins)
    idxs = size.(x, 2) #each input can have different dimensions
    s = 1
    encodings = Vector{Vector}(undef, 0)
    for (i, cidx) in enumerate(idxs)
        variable_subset = s:(s + cidx - 1)
        s += cidx
        y = @views joint_bins[:, variable_subset]
        for j in size(y, 2)
            push!(encodings, y[:, j])
        end
    end

    return encodings
end

# A version of `cartesian_bin_index` that directly returns the joint bin encoding
# instead of converting it to a cartesian index.
function encode_as_tuple(e::RectangularBinEncoding, point::SVector{D, T}) where {D, T}
    ranges = e.ranges
    if e.precise
        # Don't know how to make this faster unfurtunately...
        bin = map(searchsortedlast, ranges, point)
    else
        bin = floor.(Int, (point .- e.mini) ./ e.widths) .+ 1
    end
    return bin
end