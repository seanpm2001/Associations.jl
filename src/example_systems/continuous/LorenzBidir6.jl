using DynamicalSystemsBase: ContinuousDynamicalSystem
using StaticArrays: SVector

export LorenzBidir6

"""
    LorenzBidir6 <: ContinuousDefinition
    LorenzBidir6(; xi = [0.1, 0.05, 0.2, 0.2, 0.25, 0.3],
        c_xy = 0.2, c_yx = 0.2,
        a₁ = 10, a₂ = 28, a₃ = 8/3,
        b₁ = 10, b₂ = 28, b₃ = 9/3)

A bidirectionally coupled Lorenz-Lorenz system, where each
subsystem is a 3D Lorenz system (Amigo & Hirata, 2018)[^Amigó2018].

## Description

The dynamics is generated by the following vector field

```math
\\begin{align*}
\\dot{x_1} &= -a_1 (x_1 - x_2) + c_{yx}(y_1 - x_1) \\\\
\\dot{x_2} &= -x_1 x_3 + a_2 x_1 - x_2 \\\\
\\dot{x_3} &= x_1 x_2 - a_3 x_3 \\\\
\\dot{y_1} &= -b_1 (y_1 - y_2) + c_{xy} (x_1 - y_1) \\\\
\\dot{y_2} &= -y_1 y_3 + b_2 y_1 - y_2 \\\\
\\dot{y_3} &= y_1 y_2 - b_3 y_3
\\end{align*}
```

Default values for the parameters `a₁`, `a₂`, `a₃`, `b₁`, `b₂`, `b₃` are as in [^Amigó2018].

[^Amigó2018]:
    Amigó, José M., and Yoshito Hirata. "Detecting directional couplings from
    multivariate flows by the joint distance distribution." Chaos: An
    Interdisciplinary Journal of Nonlinear Science 28.7 (2018): 075302.
"""
Base.@kwdef struct LorenzBidir6{V, CXY, CYX, A1, A2, A3, B1, B2, B3} <: ContinuousDefinition
    xi::V = [0.1, 0.05, 0.2, 0.2, 0.25, 0.3]
    c_xy::CXY = 0.2
    c_yx::CYX = 0.2
    a₁::A1 = 10
    a₂::A2 = 28
    a₃::A3 = 8/3
    b₁::B1 = 10
    b₂::B2 = 28
    b₃::B3 = 9/3
end

function system(definition::LorenzBidir6)
    return ContinuousDynamicalSystem(eom_lorenzlorenzbidir6, definition.xi, definition)
end

@inline @inbounds function eom_lorenzlorenzbidir6(u, p, t)
    (; xi, c_xy, c_yx, a₁, a₂, a₃, b₁, b₂, b₃) = p
    x1, x2, x3, y1, y2, y3 = u

    dx1 = -a₁*(x1 - x2) + c_yx*(y1 - x1)
    dx2 = -x1*x3 + a₂*x1 - x2
    dx3 = x1*x2 - a₃*x3
    dy1 = -b₁*(y1 - y2) + c_xy*(x1 - y1)
    dy2 = -y1*y3 + b₂*y1 - y2
    dy3 = y1*y2 - b₃*y3

    return SVector{6}(dx1, dx2, dx3, dy1, dy2, dy3)
end