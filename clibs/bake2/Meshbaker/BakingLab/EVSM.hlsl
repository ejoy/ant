//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

float2 GetEVSMExponents(in float positiveExponent, in float negativeExponent,
                        in float3 cascadeScale)
{

    const float maxExponent = 42.0f;

    float2 lightSpaceExponents = float2(positiveExponent, negativeExponent);

    // Make sure exponents say consistent in light space regardless of partition
    // scaling. This prevents the exponentials from ever getting too rediculous
    // and maintains consistency across partitions.
    // Clamp to maximum range of fp32/fp16 to prevent overflow/underflow
    return min(lightSpaceExponents / cascadeScale.z, maxExponent);
}

// Input depth should be in [0, 1]
float2 WarpDepth(float depth, float2 exponents)
{
    // Rescale depth into [-1, 1]
    depth = 2.0f * depth - 1.0f;
    float pos =  exp( exponents.x * depth);
    float neg = -exp(-exponents.y * depth);
    return float2(pos, neg);
}

float Linstep(float a, float b, float v)
{
    return saturate((v - a) / (b - a));
}

float ReduceLightBleeding(float pMax, float amount)
{
  // Remove the [0, amount] tail and linearly rescale (amount, 1].
   return Linstep(amount, 1.0f, pMax);
}

float ChebyshevUpperBound(float2 moments, float mean, float minVariance,
                          float lightBleedingReduction)
{
    // Compute variance
    float variance = moments.y - (moments.x * moments.x);
    variance = max(variance, minVariance);

    // Compute probabilistic upper bound
    float d = mean - moments.x;
    float pMax = variance / (variance + (d * d));

    pMax = ReduceLightBleeding(pMax, lightBleedingReduction);

    // One-tailed Chebyshev
    return (mean <= moments.x ? 1.0f : pMax);
}