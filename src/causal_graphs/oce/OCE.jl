using Graphs: add_edge!
using Graphs.SimpleGraphs: SimpleDiGraph

export OCE

"""
    OCE <: GraphAlgorithm
    OCE(; utest::IndependenceTest = SurrogateTest(MIShannon(), KSG2(k = 3, w = 3)),
          ctest::C = LocalPermutationTest(CMIShannon(), MesnerShalizi(k = 3, w = 3)),
          τmax::T = 1, α = 0.05)

The optimal causation entropy (OCE) algorithm for causal discovery (Sun et al.,
2015)[^Sun2015].

## Description

The OCE algorithm has three steps to determine the parents of a variable `xᵢ`.
1. Perform pairwise independence tests using `utest` and select the variable `xⱼ(-τ)`
    that has the highest significant (i.e. with associated p-value below `α`)
    association with `xᵢ(0)`. Assign it to the set of selected parents `P`.
2. Perform conditional independence tests using `ctest`, finding the parent
    `Pₖ` that has the highest association with `xᵢ` given the already selected parents,
    and add it to `P`.
    Repeat until no more variables with significant association are found.
3. Backwards elimination of parents `Pₖ` of `xᵢ(0)` for which `xᵢ(0) ⫫ Pₖ | P - {Pₖ}`,
    where `P` is the set of parent nodes found in the previous steps.

`τmax` indicates the maximum lag `τ` between the target variable `xᵢ(0)` and
its potential parents `xⱼ(-τ)`. Sun et al. 2015's method is based on `τmax = 1`.

## Returns

When used with [`infer_graph`](@ref), it returns a vector `p`, where `p[i]` are the
parents for each input variable. This result can be converted to a `SimpleDiGraph`
from Graphs.jl (see [example](@ref oce_example)).

## Examples

- [Inferring time series graph from a chain of logistic maps](@ref oce_example)

[^Sun2015]:
    Sun, J., Taylor, D., & Bollt, E. M. (2015). Causal network inference by optimal
    causation entropy. SIAM Journal on Applied Dynamical Systems, 14(1), 73-106.
"""
Base.@kwdef struct OCE{U, C, T} <: GraphAlgorithm
    utest::U = SurrogateTest(MIShannon(), KSG2(k = 3, w = 3), nshuffles = 100)
    ctest::C = LocalPermutationTest(CMIShannon(), MesnerShalizi(k = 3, w = 3), nshuffles = 100)
    τmax::T = 1
    α = 0.05
end

function infer_graph(alg::OCE, x; verbose = true)
    return select_parents(alg, x; verbose)
end

function infer_graph(alg::OCE, x::AbstractDataset; verbose = true)
    return infer_graph(alg, columns(x); verbose)
end

"""
    select_parents(alg::OCE, x)

The parent selection step of the [`OCE`](@ref) algorithm, which identifies the
parents of each `xᵢ ∈ x`, assuming that `x` must be integer-indexable, i.e.
`x[i]` yields the `i`-th variable.
"""
function select_parents(alg::OCE, x; verbose = false)

    # Find the parents of each variable.
    parents = [select_parents(alg, x, k; verbose) for k in eachindex(x)]
    return parents
end

# A simple struct that stores information about selected parents.
Base.@kwdef mutable struct OCESelectedParents{P, PJ, PT}
    i::Int
    parents::P = Vector{Vector{eltype(1.0)}}(undef, 0)
    parents_js::PJ = Vector{Int}(undef, 0)
    parents_τs::PT = Vector{Int}(undef, 0)
end

function selected(o::OCESelectedParents)
    js, τs = o.parents_js, o.parents_τs
    @assert length(js) == length(τs)
    return join(["x$(js[i])($(τs[i]))" for i in eachindex(js)], ", ")
end

function Base.show(io::IO, x::OCESelectedParents)
    s = ["x$(x.parents_js[i])($(x.parents_τs[i]))" for i in eachindex(x.parents)]
    all = "x$(x.i)(0) ← $(join(s, ", "))"
    show(io, all)
end

function SimpleDiGraph(v::Vector{<:CausalityTools.OCESelectedParents})
    N = length(v)
    g = SimpleDiGraph(N)
    for k = 1:N
        parents = v[k]
        for (j, τ) in zip(parents.parents_js, parents.parents_τs)
            if j != k # avoid self-loops
                add_edge!(g, j, k)
            end
        end
    end
    return g
end

function select_parents(alg::OCE, x, i::Int; verbose = false)
    τs, js, 𝒫s = prepare_embeddings(alg, x, i)

    verbose && println("\nInferring parents for x$i(0)...")
    # Account for the fact that the `𝒫ⱼ ∈ 𝒫s` are embedded. This means that some points are
    # lost from the `xᵢ`s.
    xᵢ = @views x[i][alg.τmax+1:end]
    N = length(τs)
    parents = OCESelectedParents(i = i)

    ###################################################################
    # Forward search
    ###################################################################
    # 1. Can we find a significant pairwise association?
    verbose && println("˧ Querying pairwise associations...")

    significant_pairwise = select_parent!(alg, parents, τs, js, 𝒫s, xᵢ, i; verbose)

    if significant_pairwise
        verbose && println("˧ Querying new variables conditioned on already selected variables...")
        # 2. Continue until there are no more significant conditional pairwise associations
        significant_cond = true
        while significant_cond
            significant_cond = select_parent!(alg, parents, τs, js, 𝒫s, xᵢ, i; verbose)
        end

        ###################################################################
        # Backward elimination
        ###################################################################
        backwards_eliminate!(alg, parents, xᵢ, i; verbose)
    end
    return parents
end


function prepare_embeddings(alg::OCE, x, i)
    # Preliminary parents
    τs = Iterators.flatten([-1:-1:-alg.τmax |> collect for xᵢ in x]) |> collect
    js = Iterators.flatten([fill(i, alg.τmax) for i in eachindex(x)]) |> collect
    embeddings = [genembed(xᵢ, -1:-1:-alg.τmax) for xᵢ in x]
    T = typeof(1.0)
    𝒫s = Vector{Vector{T}}(undef, 0)
    for emb in embeddings
        append!(𝒫s, columns(emb))
    end
    return τs, js, 𝒫s
end

function pairwise_test(parents::OCESelectedParents)
    # Have any parents been identified yet? If not, then we're doing pairwise tests.
    pairwise = isempty(parents.parents)

    return pairwise
end

function select_parent!(alg::OCE, parents, τs, js, 𝒫s, xᵢ, i::Int; verbose = true)
    # If there are no potential parents to pick from, return immediately.
    isempty(𝒫s) && return false

    # Anonymous two-argument functions for computing raw measure and performing
    # independence tests, taking care of conditioning on parents when necessary.
    compute_raw_measure, test_independence = rawmeasure_and_independencetest(alg, parents)

    # Compute the measure without significance testing first. This avoids unnecessary
    # independence testing, which takes a lot of time.
    Is = zeros(length(𝒫s))
    for (i, Pⱼ) in enumerate(𝒫s)
        Is[i] = compute_raw_measure(xᵢ, Pⱼ)
    end

    # First sort variables according to maximal measure. Then, we select the first lagged
    # variable that gives significant association with the target variable.
    idxs_that_maximize_measure = sortperm(Is, rev = true)

    n_checked, n_potential_vars = 0, length(𝒫s)
    while n_checked < n_potential_vars
        n_checked += 1
        ix = idxs_that_maximize_measure[n_checked]
        if Is[ix] > 0
            result = test_independence(xᵢ, 𝒫s[ix])
            if pvalue(result) < alg.α
                print_status(IndependenceStatus(), parents, τs, js, ix, i; verbose)
                update_parents_and_selected!(parents, 𝒫s, τs, js, ix)
                return true
            end
        end
    end

    # If we reach this stage, no variables have been selected.
    print_status(NoVariablesSelected(), parents, τs, js, i; verbose)
    return false
end

# For pairwise cases, we don't need to condition on any parents. For conditional
# cases, we must condition on the parents that have already been selected (`P`).
# The measures, estimators and independence tests are different for the pairwise
# and conditional case.
# This just defines the functions `compute_raw_measure` and
# `test_independence` so that they only need two input arguments, ensuring
# that `P` is always conditioned on when relevant. The two functions are returned.
function rawmeasure_and_independencetest(alg, parents::OCESelectedParents)
    if pairwise_test(parents)
        measure, est = alg.utest.measure, alg.utest.est
        compute_raw_measure = (xᵢ, Pⱼ) -> estimate(measure, est, xᵢ, Pⱼ)
        test_independence = (xᵢ, Pix) -> independence(alg.utest, xᵢ, Pix)
    else
        measure, est = alg.ctest.measure, alg.ctest.est
        P = StateSpaceSet(parents.parents...)
        compute_raw_measure = (xᵢ, Pⱼ) -> estimate(measure, est, xᵢ, Pⱼ, P)
        test_independence = (xᵢ, Pix) -> independence(alg.ctest, xᵢ, Pix, P)
    end
    return compute_raw_measure, test_independence
end

function update_parents_and_selected!(parents::OCESelectedParents, 𝒫s, τs, js, ix::Int)
    push!(parents.parents, 𝒫s[ix])
    push!(parents.parents_js, js[ix])
    push!(parents.parents_τs, τs[ix])
    deleteat!(𝒫s, ix)
    deleteat!(js, ix)
    deleteat!(τs, ix)
end

###################################################################
# Pretty printing
###################################################################
struct NoVariablesSelected end
function print_status(::NoVariablesSelected, parents::OCESelectedParents,
        τs, js, i::Int; verbose = true)

    pairwise = pairwise_test(parents)
    if verbose && !pairwise
        # No more associations were found
        s = ["x$i(1) ⫫ x$j($τ) | $(selected(parents)))" for (τ, j) in zip(τs, js)]
        println("\t$(join(s, "\n\t"))")
    end
    if verbose && pairwise
        s = ["x$i(0) ⫫ x$j($τ) | ∅)" for (τ, j) in zip(τs, js)]
        println("\t$(join(s, "\n\t"))")
    end
end

struct IndependenceStatus end
function print_status(::IndependenceStatus, parents::OCESelectedParents,
        τs, js, ix::Int, i::Int; verbose)
    if verbose
        if pairwise_test(parents)
            println("\tx$i(0) !⫫ x$(js[ix])($(τs[ix])) | ∅")
        else
            println("\tx$i(0) !⫫ x$(js[ix])($(τs[ix])) | $(selected(parents))")
        end
    end
end

"""
    backwards_eliminate!(alg::OCE, parents::OCESelectedParents, x, i; verbose)

Algorithm 2.2 in Sun et al. (2015). Perform backward elimination for the `i`-th variable
in `x`, given the previously inferred `parents`, which were deduced using parameters in
`alg`. Modifies `parents` in-place.
"""
function backwards_eliminate!(alg::OCE, parents::OCESelectedParents, xᵢ, i::Int; verbose)
    length(parents.parents) < 2 && return parents

    verbose && println("˧ Backwards elimination...")
    n_initial = length(parents.parents_js)
    q = 0
    variable_was_eliminated = true
    while variable_was_eliminated && length(parents.parents_js) >= 2 && q < n_initial
        q += 1
        variable_was_eliminated = eliminate_loop!(alg, parents, xᵢ, i; verbose)
    end
    return parents
end

"""
    eliminate_loop!(alg::OCE, parents::OCESelectedParents, xᵢ; verbose = false)

Inner portion of algorithm 2.2 in Sun et al. (2015). This method is called in an external
while-loop that handles the variable elimination step in their line 3.
"""
function eliminate_loop!(alg::OCE, parents::OCESelectedParents, xᵢ, i; verbose = false)
    isempty(parents.parents) && return false
    M = length(parents.parents)
    P = parents.parents
    variable_was_eliminated = false
    for k in eachindex(P)
        Pj = P[k]
        remaining_idxs = setdiff(1:M, k)
        remaining = StateSpaceSet(P[remaining_idxs]...)
        test = independence(alg.ctest, xᵢ, Pj, remaining)

        if verbose
            τ, j = parents.parents_τs[k], parents.parents_js[k] # Variable currently considered
            τs = parents.parents_τs
            js = parents.parents_js
            src_var = "x$j($τ)"
            targ_var = "x$i(0)"
            cond_var = join(["x$(js[r])($(τs[r]))" for r in remaining_idxs], ", ")

            if test.pvalue >= alg.α
                outcome_msg = "Removing x$(j)($τ) from parent set"
                println("\t$src_var ⫫ $targ_var | $cond_var → $outcome_msg")
            else
                outcome_msg = "Keeping x$(j)($τ) in parent set"
                println("\t$src_var !⫫ $targ_var | $cond_var → $outcome_msg")
            end
        end

        # A parent became independent of the target conditional on the remaining parents
        if test.pvalue >= alg.α
            deleteat!(parents.parents, k)
            deleteat!(parents.parents_js, k)
            deleteat!(parents.parents_τs, k)
            variable_was_eliminated = true
            break
        end
    end

    return variable_was_eliminated
end
