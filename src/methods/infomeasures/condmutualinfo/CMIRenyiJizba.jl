"""
    CMIRenyiJizba <: ConditionalMutualInformation

The Rényi conditional mutual information ``I_q^{R_{J}}(X; Y | Z`` defined in Jizba et
al. (2012)[^Jizba2012].

## Definition

```math
I_q^{R_{J}}(X; Y | Z) = I_q^{R_{J}}(X; Y, Z) - I_q^{R_{J}}(X; Z),
```

where ``I_q^{R_{J}}(X; Z)`` is the [`MIRenyiJizba`](@ref) mutual information.

[^Jizba2012]:
    Jizba, P., Kleinert, H., & Shefaat, M. (2012). Rényi’s information transfer between
    financial time series. Physica A: Statistical Mechanics and its Applications,
    391(10), 2971-2989.
"""
struct CMIRenyiJizba{E <: Renyi} <: ConditionalMutualInformation{E}
    e::E
    function CMIRenyiJizba(; base = 2, q = 1.5)
        e = Renyi(; base, q)
        new{typeof(e)}(e)
    end
    function CMIRenyiJizba(e::E) where E <: Renyi
        new{E}(e)
    end
end

function estimate(measure::CMIRenyiJizba, est::ProbOrDiffEst, x, y, z)
    HXZ, HYZ, HXYZ, HZ = marginal_entropies_cmi4h(measure, est, x, y, z)
    return HXZ + HYZ - HXYZ - HZ
end
