#ifndef __EVSM_UTILS_SH__
#define __EVSM_UTILS_SH__

//code from: https://github.com/TheRealMJP/Shadows/blob/master/Shadows/VSM.hlsl

//TODO: seprarte to warp_depth_positive/warp_depth_nagitive for RG and RGBA format

float warp_depth_positive(float depth, float exponent)
{
    const float d = 2.0 * depth - 1.0;
    return exp(exponent * d);
}

vec2 warp_depth(float depth, vec2 exponents)
{
    // Rescale depth into [-1, 1]
    depth = 1.0 - depth;
    depth = 2.0 * depth - 1.0;
    float pos =  exp( exponents.x * depth);
    float neg = -exp(-exponents.y * depth);
    return vec2(pos, neg);
}

float linear_step(float a, float b, float v)
{
    return saturate((v - a) / (b - a));
}

// Reduces VSM light bleedning
float reduce_light_bleeding(float pMax, float amount)
{
    // can use smoothstep()
    // Remove the [0, amount] tail and linearly rescale (amount, 1].
    return linear_step(amount, 1.0f, pMax);
}

float chebyshev_upper_bound(vec2 moments, float mean, float min_variance, float light_bleeding)
{
    // Compute variance
    float variance = moments.y - (moments.x * moments.x);
    variance = max(variance, min_variance);

    // Compute probabilistic upper bound
    float d = mean - moments.x;
    float pMax = variance / (variance + (d * d));

    pMax = reduce_light_bleeding(pMax, light_bleeding);

    // One-tailed Chebyshev
    return (mean <= moments.x ? 1.0f : pMax);
}

#endif //__EVSM_UTILS_SH__