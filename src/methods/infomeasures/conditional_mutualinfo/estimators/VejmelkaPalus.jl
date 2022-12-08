using Neighborhood: bulkisearch, inrangecount
using Neighborhood: Theiler, NeighborNumber, KDTree, Chebyshev
using SpecialFunctions: digamma

export VejmelkaPalus

"""
    VejmelkaPalus <: ConditionalMutualInformationEstimator
    VejmelkaPalus(k = 1, w = 0)

The `VejmelkaPalus` estimator uses a `k`-th nearest neighbor approach to
compute conditional mutual information (Vejmelka & Paluš)[^Vejmelka2008].

This estimator is identical to the [`FrenzelPompe`](@ref) estimator,
which appeared in a separate paper around the same time.

`w` is the Theiler window.

[^Vejmelka2008]:
    Vejmelka, M., & Paluš, M. (2008). Inferring the directionality of coupling with
    conditional mutual information. Physical Review E, 77(2), 026214.
"""
Base.@kwdef struct VejmelkaPalus{MJ, MM} <: ConditionalMutualInformationEstimator
    k::Int = 1
    w::Int = 0
    metric_joint::MJ = Chebyshev()
    metric_marginals::MM = Chebyshev()
end

function estimate(infomeasure::CMI{Nothing}, e::Renyi, est::VejmelkaPalus, x, y, z)
    e.q ≈ 1 || throw(ArgumentError(
        "Renyi entropy with q = $(e.q) not implemented for $(typeof(est)) estimators"
    ))
    (; k, w, metric_joint, metric_marginals) = est
    # Ensures that vector-valued inputs are converted to datasets, so that
    # building the marginal/joint spaces and neighbor searches are fast.
    X = Dataset(x)
    Y = Dataset(y)
    Z = Dataset(z)
    @assert length(X) == length(Y) == length(Z)
    N = length(X)

    joint = Dataset(X, Y, Z)
    XZ = Dataset(X, Z)
    YZ = Dataset(Y, Z)

    tree_joint = KDTree(joint, metric_joint)
    ds_joint = last.(bulksearch(tree_joint, joint, NeighborNumber(k), Theiler(w))[2])
    tree_xz = KDTree(XZ, metric_marginals)
    tree_yz = KDTree(YZ, metric_marginals)
    tree_z = KDTree(Z, metric_marginals)

    cmi = digamma(k) -
        estimate_digammas(tree_xz, tree_yz, tree_z, XZ, YZ, Z, ds_joint, N)

    return cmi / log(e.base, ℯ)
end

estimate(infomeasure::CMI, est::VejmelkaPalus, args...; base = 2, kwargs...) =
    estimate(infomeasure, Shannon(; base), est, args...; kwargs...)

function estimate_digammas(tree_xz, tree_yz, tree_z, XZ, YZ, Z, ds_joint, N)
    mean_dgs = 0.0
    for (i, dᵢ) in enumerate(ds_joint)
        # Usually, we subtract 1 because inrangecount includes the point itself,
        # but we'll have to add it again inside the digamma, so just skip it.
        nxz = inrangecount(tree_xz, XZ[i], dᵢ)
        nxy = inrangecount(tree_yz, YZ[i], dᵢ)
        nz = inrangecount(tree_z, Z[i], dᵢ)
        mean_dgs += digamma(nxz) + digamma(nxy) - digamma(nz)
    end

    return mean_dgs / N
end
