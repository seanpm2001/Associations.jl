# [Independence testing](@id examples_independence)

## [[`JointDistanceDistributionTest`](@ref)](@id quickstart_jddtest)

### Bidirectionally coupled logistic maps

Let's use the built-in `logistic2_bidir` discrete dynamical system to create a pair of
bidirectionally coupled time series and use the [`JointDistanceDistributionTest`](@ref)
to see if we can confirm from observed time series that these variables are
bidirectionally coupled. We'll use a significance level of `1 - α = 0.99`, i.e. `α = 0.01`.

We start by generating some time series and configuring the test.

```@example quickstart_jddtest_logistic
using CausalityTools
sys = logistic2_bidir(c_xy = 0.5, c_yx = 0.4)
x, y = columns(trajectory(sys, 2000, Ttr = 10000))
measure = JointDistanceDistribution(D = 5, B = 5)
test = JointDistanceDistributionTest(measure)
```

Now, we test for independence in both directions.

```@example quickstart_jddtest_logistic
independence(test, x, y)
```

```@example quickstart_jddtest_logistic
independence(test, y, x)
```

As expected, the null hypothesis is rejected in both directions at the pre-determined 
significance level, and hence we detect directional coupling in both directions.

## Non-coupled logistic maps

What happens in the example above if there is no coupling?

```@example quickstart_jddtest_logistic
sys = logistic2_bidir(c_xy = 0.00, c_yx = 0.0)
x, y = columns(trajectory(sys, 1000, Ttr = 10000));
rxy = independence(test, x, y)
ryx = independence(test, y, x)
pvalue(rxy), pvalue(ryx)
```

At significance level `0.99`, we can't reject the null in either direction, hence there's not
enough evidence in the data to suggest directional coupling.

## [`LocalPermutationTest`](@ref)

### Conditional mutual information (Shannon, differential)

#### Chain of random variables $X \to Y \to Z$

Here, we'll create a three-variable scenario where `X` and `Z` are connected through `Y`,
so that ``I(X; Z | Y) = 0`` and ``I(X; Y | Z) > 0``. We'll test for conditional
independence using Shannon conditional mutual information
([`CMIShannon`](@ref)). To estimate CMI, we'll use the [`Kraskov`](@ref) differential
entropy estimator, which naively computes CMI as a sum of entropy terms without guaranteed
bias cancellation.

```@example LOCAL_PERMUTATION_TEST
using CausalityTools

X = randn(1000)
Y = X .+ randn(1000) .* 0.4
Z = randn(1000) .+ Y
x, y, z = Dataset.((X, Y, Z))
test = LocalPermutationTest(CMIShannon(base = 2), Kraskov(k = 10), nshuffles = 30)
test_result = independence(test, x, y, z)
```

We expect there to be a detectable influence from ``X`` to
``Y``, if we condition on ``Z`` or not, because ``Z`` doesn't influence neither ``X`` nor ``Y``.
The null hypothesis is that the first two variables are conditionally independent given the third, which we reject with a very low p-value. Hence, we accept the alternative
hypothesis that the first two variables ``X`` and ``Y``. are conditionally *dependent* given ``Z``.

```@example LOCAL_PERMUTATION_TEST
test_result = independence(test, x, z, y)
```

As expected, we cannot reject the null hypothesis that ``X`` and ``Z`` are conditionally independent given ``Y``, because ``Y`` is the variable that transmits information from
``X`` to ``Z``.

## [[`SurrogateTest`](@ref)](@id examples_surrogatetest)

## [Distance correlation](@id examples_surrogatetest_distancecorrelation)

```@example
using CausalityTools
x = randn(1000)
y = randn(1000) .+ 0.5x
independence(SurrogateTest(DistanceCorrelation()), x, y)
```

### [Partial correlation](@id examples_surrogatetest_partialcorrelation)

```@example
using CausalityTools
x = randn(1000)
y = randn(1000) .+ 0.5x
z = randn(1000) .+ 0.8y
independence(SurrogateTest(PartialCorrelation()), x, z, y)
```

### [Mutual information ([`MIShannon`](@ref), categorical)](@id examples_surrogatetest_mishannon_categorical)

In this example, we expect the `preference` and the `food` variables to be independent.

```@example
using CausalityTools
# Simulate 
n = 1000
preference = rand(["yes", "no"], n)
food = rand(["veggies", "meat", "fish"], n)
test = SurrogateTest(MIShannon(), Contingency())
independence(test, preference, food)
```

As expected, there's not enough evidence to reject the null hypothesis that the
variables are independent.

### [Conditional mutual information ([`CMIShannon`](@ref), categorical)](@id examples_surrogatetest_cmishannon_categorical)

Here, we simulate a survey at a ski resort. The data are such that the place a person
grew up is associated with how many times they fell while going skiing. The control
happens through an intermediate variable `preferred_equipment`, which indicates what
type of physical activity the person has engaged with in the past. Some activities
like skateboarding leads to better overall balance, so people that are good on
a skateboard also don't fall, and people that to less challenging activities fall
more often.

We should be able to reject `places ⫫ experience`, but not reject
`places ⫫ experience | preferred_equipment`.  Let's see if we can detect these
relationships using (conditional) mutual information.

```@example indep_cmi
using CausalityTools
n = 10000

places = rand(["city", "countryside", "under a rock"], n);
preferred_equipment = map(places) do place
    if cmp(place, "city") == 1
        return rand(["skateboard", "bmx bike"])
    elseif cmp(place, "countryside") == 1
        return rand(["sled", "snowcarpet"])
    else
        return rand(["private jet", "ferris wheel"])
    end
end;
experience = map(preferred_equipment) do equipment
    if equipment ∈ ["skateboard", "bmx bike"]
        return "didn't fall"
    elseif equipment ∈ ["sled", "snowcarpet"]
        return "fell 3 times or less"
    else
        return "fell uncontably many times"
    end
end;

test_mi = independence(SurrogateTest(MIShannon(), Contingency()), places, experience)
```

As expected, the evidence favors the alternative hypothesis that `places` and 
`experience` are dependent.

```@example  indep_cmi
test_cmi = independence(SurrogateTest(CMIShannon(), Contingency()), places, experience, preferred_equipment)
```

Again, as expected, when conditioning on the mediating variable, the dependence disappears,
and we can't reject the null hypothesis of independence.

### Transfer entropy ([`TEShannon`](@ref))

#### [Pairwise](@id examples_surrogatetest_teshannon)

We'll see if we can reject independence for two unidirectionally coupled timeseries
where `x` drives `y`.

```@example surrogatecit_te
using CausalityTools
sys = logistic2_unidir(c_xy = 0.5) # x affects y, but not the other way around.
x, y = columns(trajectory(sys, 1000, Ttr = 10000))

test = SurrogateTest(TEShannon(), KSG1(k = 4))
independence(test, x, y)
```

As expected, we can reject the null hypothesis that the future of `y` is independent of
`x`, because `x` does actually influence `y`. This doesn't change if we compute
partial (conditional) transfer entropy with respect to some random extra time series,
because it doesn't influence any of the other two variables.

```@example surrogatecit_te
independence(test, x, y, rand(length(x)))
```

### [[`SMeasure`](@ref)](@id examples_surrogatetest_smeasure)

```@example quickstart_smeasure
using CausalityTools
x, y = randn(3000), randn(3000)
measure = SMeasure(dx = 3, dy = 3)
s = s_measure(measure, x, y)
```

The `s` statistic is larger when there is stronger coupling and smaller
when there is weaker coupling. To check whether `s` is significant (i.e. large
enough to claim directional dependence), we can use a [`SurrogateTest`](@ref),
like [here](@ref examples_surrogatetest_smeasure).

```@example quickstart_smeasure
test = SurrogateTest(measure)
independence(test, x, y)
```

The p-value is high, and we can't reject the null at any reasonable significance level.
Hence, there isn't evidence in the data to support directional coupling from `x` to `y`.

What happens if we use coupled variables?

```@example quickstart_smeasure
z = x .+ 0.1y
independence(test, x, z)
```

Now we can confidently reject the null (independence), and conclude that there is
evidence in the data to support directional dependence from `x` to `z`.