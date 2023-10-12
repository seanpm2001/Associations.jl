export Rahimzamani

"""
    Rahimzamani <: ConditionalMutualInformationEstimator
    Rahimzamani(k = 1, w = 0)

The `Rahimzamani` estimator, short for Rahimzamani-Asnani-Viswanath-Kannan,
is an estimator for Shannon conditional mutual information for data that can be mixtures of
discrete and continuous data [Rahimzamani2018](@cite).

This is very similar to the [`GaoKannanOhViswanath`](@ref) mutual information estimator,
but has been expanded to the conditional case.
"""
struct Rahimzamani{M <: ConditionalMutualInformation, ME} <: ConditionalMutualInformationEstimator{M}
    definition::M
    k::Int
    w::Int
    metric::ME
end

function Rahimzamani(definition = CMIShannon(); k = 1, w = 0)
    # Metric shouldn't be modified by the user.
    metric = Chebyshev()
    return Rahimzamani(definition, k, w, metric)
end

function information(est::Rahimzamani{<:CMIShannon}, x, y, z)
    (; definition, k, w, metric) = est

    X = StateSpaceSet(x)
    Y = StateSpaceSet(y)
    Z = StateSpaceSet(z)
    joint = StateSpaceSet(X, Y, Z)
    XZ = StateSpaceSet(x, z)
    YZ = StateSpaceSet(y, z)
    Z = StateSpaceSet(z)

    N = length(joint)
    M = 3
    tree_joint = KDTree(joint, metric)
    ds_joint = last.(bulksearch(tree_joint, joint, NeighborNumber(k), Theiler(w))[2])
    tree_xz = KDTree(XZ, metric)
    tree_yz = KDTree(YZ, metric)
    tree_z = KDTree(Z, metric)

    condmi = 0.0
    for i = 1:N
        # The notation for ρ_{i, xy} in the paper in unclear. They claim in the paper that
        # the estimator reduces to the KSG1 estimator when k̂ == k. Therefore,
        # I assume ρ_{i, xy} is the distance in the *joint* space.
        # ... but isn't this just the FPVP estimator?
        dmax = ds_joint[i]
        k̂ = dmax == 0 ? inrangecount(tree_joint, joint[i], 0.0) - 1  : k
        condmi += digamma(k̂)
        condmi -= log(inrangecount(tree_xz, XZ[i], dmax))
        condmi -= log(inrangecount(tree_yz, YZ[i], dmax))
        condmi += log(inrangecount(tree_z, Z[i], dmax))
    end
    # The "unit" is nats
    condmi /= N

    return _convert_logunit(condmi, ℯ, definition.base)
end
