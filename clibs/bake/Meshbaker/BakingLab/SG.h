//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include <PCH.h>
#include <SF11_Math.h>

using namespace SampleFramework11;

// SphericalGaussian(dir) := Amplitude * exp(Sharpness * (dot(Axis, Direction) - 1.0f))
struct SG
{
    Float3 Amplitude;
	float Sharpness = 1.0f;
    Float3 Axis;

	// exp(2 * Sharpness * (dot(Axis, Direction) - 1.0f)) integrated over the sampling domain.
	float BasisSqIntegralOverDomain;
};

// Evaluates an SG given a direction on a unit sphere
inline Float3 EvaluateSG(const SG& sg, Float3 dir)
{
    return sg.Amplitude * std::exp(sg.Sharpness * (Float3::Dot(dir, sg.Axis) - 1.0f));
}

// Computes the inner product of two SG's, which is equal to Integrate(SGx(v) * SGy(v) * dv).
inline Float3 SGInnerProduct(const SG& x, const SG& y)
{
    float umLength = Float3::Length(x.Sharpness * x.Axis + y.Sharpness * y.Axis);
    Float3 expo = std::exp(umLength - x.Sharpness - y.Sharpness) * x.Amplitude * y.Amplitude;
    float other = 1.0f - std::exp(-2.0f * umLength);
    return (2.0f * Pi * expo * other) / umLength;
}

// Returns an approximation of the clamped cosine lobe represented as an SG
inline SG CosineLobeSG(Float3 direction)
{
    SG cosineLobe;
    cosineLobe.Axis = direction;
    cosineLobe.Sharpness = 2.133f;
    cosineLobe.Amplitude = 1.17f;

    return cosineLobe;
}

// Computes the approximate integral of an SG over the entire sphere. The error vs. the
// non-approximate version decreases as sharpeness increases.
inline Float3 ApproximateSGIntegral(const SG& sg)
{
    return 2 * Pi * (sg.Amplitude / sg.Sharpness);
}

// Computes the approximate incident irradiance from a single SG lobe containing incoming radiance.
// The irradiance is computed using a fitted approximation polynomial. This approximation
// and its implementation were provided by Stephen Hill.
inline Float3 SGIrradianceFitted(const SG& lightingLobe, const Float3& normal)
{
    const float muDotN = Float3::Dot(lightingLobe.Axis, normal);
    const float lambda = lightingLobe.Sharpness;

    const float c0 = 0.36f;
    const float c1 = 1.0f / (4.0f * c0);

    float eml  = std::exp(-lambda);
    float em2l = eml * eml;
    float rl   = 1.0f / lambda;

    float scale = 1.0f + 2.0f * em2l - rl;
    float bias  = (eml - em2l) * rl - em2l;

    float x  = std::sqrt(1.0f - scale);
    float x0 = c0 * muDotN;
    float x1 = c1 * x;

    float n = x0 + x1;

    float y = (std::abs(x0) <= x1) ? n * n / x : Saturate(muDotN);

    float normalizedIrradiance = scale * y + bias;

    return normalizedIrradiance * ApproximateSGIntegral(lightingLobe);
}

// Input parameters for the solve
struct SGSolveParam
{
    // StrikePlate plate;                           // radiance over the sphere
    Float3* XSamples = nullptr;
    Float3* YSamples = nullptr;
    uint64 NumSamples = 0;

    uint64 NumSGs = 0;                              // number of SG's we want to solve for

    SG* OutSGs;                                     // output of final SG's we solve for
};

enum class SGDistribution : uint32
{
    Spherical,
    Hemispherical,
};

void InitializeSGSolver(uint64 numSGs, SGDistribution distribution);
const SG* InitialGuess();

// Solve for k-number of SG's based on a hemisphere of radiance
void SolveSGs(SGSolveParam& params);

void ProjectOntoSGs(const Float3& dir, const Float3& color, SG* outSGs, uint64 numSGs);

void SGRunningAverage(const Float3& dir, const Float3& color, SG* outSGs, uint64 numSGs, float sampleIdx, float* lobeWeights, bool nonNegative);
