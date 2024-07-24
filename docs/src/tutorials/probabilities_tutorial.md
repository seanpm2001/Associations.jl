
## [[`Counts`](@ref) and [`Probabilities`](@ref) tutorial](@id tutorial_probabilities)

Estimating multivariate counts (contingency matrices) and PMFs is simple. If the data are pre-discretized, then
we can use [`UniqueElements`](@ref) to simply count the number of occurrences.

```@example counts_probs_tutorial
using CausalityTools
n = 50 # the number of samples must be the same for each input variable
x = rand(["dog", "cat", "snake"], n)
y = rand(1:4, n)
z = rand([(2, 1), (0, 0), (1, 1)], n)
counts(UniqueElements(), x, y, z)
```

Probabilities are computed analogously, except counts are normalized.

```@example counts_probs_tutorial
probabilities(UniqueElements(), x, y, z)
```

