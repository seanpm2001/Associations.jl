
using Reexport

@reexport module SMeasure
export s_measure

using NearestNeighbors, Distances, Neighborhood, DelayEmbeddings


"""
    s_measure(x::AbstractDataset, y::AbstractDataset; 
        K::Int = 2, metric = SqEuclidean(), tree_metric = Euclidean()) → Float64
    s_measure(x::AbstractVector, y::AbstractVector; 
        K::Int = 2, metric = SqEuclidean(), tree_metric = Euclidean(),
        dx::Int = 2, my::Int = 2, τx::Int = 1, τy::Int = 1) → Float64
    s_measure(x::AbstractDataset, y::AbstractVector; 
        K::Int = 2, metric = SqEuclidean(), tree_metric = Euclidean(),
        dx::Int = 2, τx::Int = 1) → Float64
    s_measure(x::AbstractDataset, y::AbstractVector; 
        K::Int = 2, metric = SqEuclidean(), tree_metric = Euclidean(),
        dy::Int = 2, τy::Int = 1) → Float64

S-measure [^Grassberger1999][^Quiroga2000] for the directional dependence between 
univariate/multivariate time series `x` and `y`. 

Returns a scalar `s ∈ [0, 1]`, where `s = 0` indicates independence between `x` and `y`, 
and higher values indicate synchronization between `x` and `y`, with complete 
synchronization for `s = 1.0`.

## Input data 

The algorithm is slightly modified from [1] to allow univariate time series as input.
In that case, these time series are embedded using the parameters `mx`/`τx` (dimension/lag 
for time series `x`) or `my`/`τy` (dimension/lag for time series `y`). For custom embeddings,
do the embedding yourself and input `Dataset`s as both `x` and `y`.

- If `x` and `y` are `dx` and `dy`-dimensional [`Dataset`](@ref)s, respectively, 
    then use `x` and `y` as is. 
- If `x` and `y` are scalar time series, then create `dx` and `dy` dimensional embeddings,
    respectively, of both `x` and `y`, resulting in `N` different `m`-dimensional embedding points
    ``X = \\{x_1, x_2, \\ldots, x_N \\}`` and ``Y = \\{y_1, y_2, \\ldots, y_N \\}``.
    `τx` and `τy` control the embedding lags for `x` and `y`. 
- If `x` is a scalar-valued vector and `y` is a [`Dataset`](@ref), or vice versa, 
    then create an embedding of the scalar time series using parameters `dx`/`τx` or `dy`/`τy`.

In all three cases, input datasets are length-matched by eliminating points at the end of 
the longest dataset (after the embedding step, if relevant) before analysis.

## Description

1. Let ``r_{i,j}`` and ``s_{i,j}`` be the indices of the `K`-th nearest neighbors 
    of ``x_i`` and ``y_i``, respectively.

2. Compute the the mean squared Euclidean distance to the ``K`` nearest neighbors 
    for each ``x_i``, using the indices ``r_{i, j}``.

```math
R_i^{(k)}(x) = \\dfrac{1}{k} \\sum_{i=1}^{k}(x_i, x_{r_{i,j}})^2
```

- Compute the y-conditioned mean squared Euclidean distance to the ``K`` nearest 
    neighbors for each ``x_i``, now using the indices ``s_{i,j}``.

```math
R_i^{(k)}(x|y) = \\dfrac{1}{k} \\sum_{i=1}^{k}(x_i, x_{s_{i,j}})^2
```

- Define the following measure of independence, where ``0 \\leq S \\leq 1``, and 
    low values indicate independence and values close to one occur for 
    synchronized signals.

```math
S^{(k)}(x|y) = \\dfrac{1}{N} \\sum_{i=1}^{N} \\dfrac{R_i^{(k)}(x)}{R_i^{(k)}(x|y)}
```

## Example

```julia
using CausalityTools

# A two-dimensional Ulam lattice map
sys = ulam(2)

# Sample 1000 points after discarding 5000 transients
orbit = trajectory(sys, 1000, Ttr = 5000)
x, y = orbit[:, 1], orbit[:, 2]

# 4-dimensional embedding for `x`, 5-dimensional embedding for `y`
s_measure(x, y, dx = 4, τx = 3, dy = 5, τy = 1)
```

[^Quiroga2000]: Quian Quiroga, R., Arnhold, J. & Grassberger, P. [2000] “Learning driver-response relationships from synchronization patterns,” Phys. Rev. E61(5), 5142–5148.
[^Grassberger1999]: Arnhold, J., Grassberger, P., Lehnertz, K., & Elger, C. E. (1999). A robust method for detecting interdependences: application to intracranially recorded EEG. Physica D: Nonlinear Phenomena, 134(4), 419-430.
"""
function s_measure(x::AbstractDataset{D1, T}, y::AbstractDataset{D2, T}; K::Int = 3, 
        metric = SqEuclidean(),
        tree_metric = Euclidean(),
        theiler_window::Int = 0 # only point itself excluded
        ) where {D1, D2, T}
    
    # Match length of datasets by excluding end points.
    lx = length(x); ly = length(y)
    lx > ly ? X = x[1:ly, :] : X = x
    ly > lx ? Y = y[1:lx, :] : Y = y
    N = length(X)

    # Pre-allocate vectors to hold indices and distances during loops
    dists_x = zeros(T, K)
    dists_x_cond_y = zeros(T, K)

    # Mean squared distances in X, and 
    # mean squared distances in X conditioned on Y
    Rx = zeros(T, N)
    Rx_cond_y = zeros(T, N)

    # Search for the K nearest neighbors of each points in both X and Y
    treeX = searchstructure(KDTree, X, tree_metric)
    treeY = searchstructure(KDTree, Y, tree_metric)
    neighborhoodtype, theiler = NeighborNumber(K), Theiler(0)
    idxs_X = bulkisearch(treeX, X, neighborhoodtype, theiler)
    idxs_Y = bulkisearch(treeY, Y, neighborhoodtype, theiler)
    
    for n in 1:N
        pxₙ = X[n]
    
        for j = 1:K
            rₙⱼ = idxs_X[n][j] # nearest neighbor indices in X
            sₙⱼ = idxs_Y[n][j] # nearest neighbor indices in Y
            dists_x[j] = evaluate(metric, pxₙ, X[rₙⱼ])
            dists_x_cond_y[j] = evaluate(metric, pxₙ, X[sₙⱼ])
        end
        
        Rx[n] = sum(dists_x) / K
        Rx_cond_y[n] = sum(dists_x_cond_y) / K
    end
    
    return sum(Rx ./ Rx_cond_y) / N
end

function s_measure(x::AbstractVector{T}, y::AbstractVector{T}; K::Int = 3,
    dx::Int = 2, dy::Int = 2, τx = 1, τy = 1, metric = SqEuclidean(),
    tree_metric = Euclidean()) where T

    X = embed(x, dx, τx)
    Y = embed(y, dy, τy)
    lX, lY = length(X), length(Y)

    s_measure(
        # TODO: cut the last points of the shortest resulting embedding.
        lX > lY ? X[1:lY, :] : X, 
        lY > lX ? Y[1:lX, :] : Y, 
        K = K, metric = metric, tree_metric = tree_metric)
end

function s_measure(X::AbstractDataset{D}, y::AbstractVector{T}; K::Int = 3,
        dy::Int = 2, τy = 1, 
        metric = SqEuclidean(), tree_metric = Euclidean()) where {D, T}

    Y = embed(y, dy, τy)
    s_measure(X[1:length(Y), :], Y, K = K, metric = metric, tree_metric = tree_metric)
end

function s_measure(x::AbstractVector{T}, Y::AbstractDataset{D}; K::Int = 3,
        dx::Int = 2, τx = 1, metric = SqEuclidean(),
        tree_metric = Euclidean()) where {D, T}
    X = embed(x, dx, τx)

    s_measure(X, Y[1:length(X), :], K = K, metric = metric, tree_metric = tree_metric)
end


end