//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#define EIGEN_MPL2_ONLY
#include "../Externals/eigen/Eigen/Dense"
#include "../Externals/eigen/Eigen/NNLS"

#include "../Externals/eigen/unsupported/Eigen/NonLinearOptimization"
#include "../Externals/eigen/unsupported/Eigen/NumericalDiff"

#include "SG.h"
#include <FileIO.h>
#include "AppSettings.h"
#include <Graphics/Sampling.h>

static SG defaultInitialGuess[AppSettings::MaxSGCount];
static bool eigenInitialized = false;

// Generate uniform spherical gaussians on the sphere or hemisphere
void GenerateUniformSGs(SG* outSGs, uint64 numSGs, SGDistribution distribution)
{
    const uint64 N = distribution == SGDistribution::Hemispherical ? numSGs * 2 : numSGs;

    Float3 means[AppSettings::MaxSGCount * 2];

    float inc = Pi * (3.0f - std::sqrt(5.0f));
    float off = 2.0f / N;
    for(uint64 k = 0; k < N; ++k)
    {
        float y = k * off - 1.0f + (off / 2.0f);
        float r = std::sqrt(1.0f - y * y);
        float phi = k * inc;
        means[k] = Float3(std::cos(phi) * r, std::sin(phi) * r, y);
    }

    uint64 currSG = 0;
    for(uint64 i = 0; i < N; ++i)
    {
        // For the sphere we always accept the sample point but for the hemisphere we only accept
        // sample points on the correct side of the hemisphere
        if(distribution == SGDistribution::Spherical || Float3::Dot(means[i].z, Float3(0.0f, 0.0f, 1.0f)) >= 0.0f)
        {
            SG sample;
            sample.Axis = Float3::Normalize(means[i]);
            outSGs[currSG++] = sample;
        }
    }

    float minDP = 1.0f;
    for(uint64 i = 1; i < numSGs; ++i)
    {
        Float3 h = Float3::Normalize(outSGs[i].Axis + outSGs[0].Axis);
        minDP = Min(minDP, Float3::Dot(h, outSGs[0].Axis));
    }

    float sharpness = (std::log(0.65f) * numSGs) / (minDP - 1.0f);

    for(uint32 i = 0; i < numSGs; ++i)
        outSGs[i].Sharpness = sharpness;

    const uint64 sampleCount = 2048;
    Float2 samples[sampleCount];
    GenerateHammersleySamples2D(samples, sampleCount);

    for(uint32 i = 0; i < numSGs; ++i)
        outSGs[i].BasisSqIntegralOverDomain = 0.0f;

    for(uint64 i = 0; i < sampleCount; ++i)
    {
        Float3 dir = distribution == SGDistribution::Hemispherical ? SampleDirectionHemisphere(samples[i].x, samples[i].y)
                                                                   : SampleDirectionSphere(samples[i].x, samples[i].y);
        for(uint32 j = 0; j < numSGs; ++j)
        {
            float weight = std::exp(outSGs[j].Sharpness * (Float3::Dot(dir, outSGs[j].Axis) - 1.0f));
            outSGs[j].BasisSqIntegralOverDomain += (weight * weight - outSGs[j].BasisSqIntegralOverDomain) / float(i + 1);
        }
    }
}

void InitializeSGSolver(uint64 numSGs, SGDistribution distribution)
{
    if(eigenInitialized == false)
    {
        Eigen::initParallel();
        eigenInitialized = true;
    }

	GenerateUniformSGs(defaultInitialGuess, numSGs, distribution);
}

const SG* InitialGuess()
{
    return defaultInitialGuess;
}

// Solve for SG's using non-negative least squares
static void SolveNNLS(SGSolveParam& params)
{
    Assert_(params.XSamples != nullptr);
    Assert_(params.YSamples != nullptr);

    // -- Linearly solve for the rgb channels one at a time
    Eigen::MatrixXf Ar, Ag, Ab;
    Ar.resize(params.NumSamples, int64(params.NumSGs));
    Ag.resize(params.NumSamples, int64(params.NumSGs));
    Ab.resize(params.NumSamples, int64(params.NumSGs));
    Eigen::VectorXf br(params.NumSamples);
    Eigen::VectorXf bg(params.NumSamples);
    Eigen::VectorXf bb(params.NumSamples);
    for(uint32 i = 0; i < params.NumSamples; ++i)
    {
        // compute difference squared from actual observed data
        for(uint32 j = 0; j < params.NumSGs; ++j)
        {
            float exponent = exp((Float3::Dot(params.XSamples[i], params.OutSGs[j].Axis) - 1.0f) *
                                 params.OutSGs[j].Sharpness);
            Ar(i,j) = exponent;
            Ag(i,j) = exponent;
            Ab(i,j) = exponent;
        }
        br(i) = params.YSamples[i].x;
        bg(i) = params.YSamples[i].y;
        bb(i) = params.YSamples[i].z;
    }

    Eigen::NNLS<Eigen::MatrixXf> nnlsr(Ar);
    Eigen::NNLS<Eigen::MatrixXf> nnlsg(Ag);
    Eigen::NNLS<Eigen::MatrixXf> nnlsb(Ab);
    nnlsr.solve(br);
    nnlsg.solve(bg);
    nnlsb.solve(bb);
    Eigen::VectorXf rchan = nnlsr.x();
    Eigen::VectorXf gchan = nnlsg.x();
    Eigen::VectorXf bchan = nnlsb.x();

    for(uint32 j = 0; j < params.NumSGs; ++j)
    {
        params.OutSGs[j].Amplitude.x = rchan[j];
        params.OutSGs[j].Amplitude.y = gchan[j];
        params.OutSGs[j].Amplitude.z = bchan[j];
    }
}

// Solve for SG's using singular value decomposition
static void SolveSVD(SGSolveParam& params)
{
	// -- Linearly solve for the rgb channels one at a time
	Eigen::MatrixXf Ar, Ag, Ab;

	Ar.resize(params.NumSamples, params.NumSGs);
	Ag.resize(params.NumSamples, params.NumSGs);
	Ab.resize(params.NumSamples, params.NumSGs);
	Eigen::VectorXf br(params.NumSamples);
	Eigen::VectorXf bg(params.NumSamples);
	Eigen::VectorXf bb(params.NumSamples);
	for(uint32 i = 0; i < params.NumSamples; ++i)
	{
		// compute difference squared from actual observed data
		for(uint32 j = 0; j < params.NumSGs; ++j)
		{
			float exponent = std::exp((Float3::Dot(params.XSamples[i], params.OutSGs[j].Axis) - 1.0f) *
				                      params.OutSGs[j].Sharpness);
			Ar(i, j) = exponent;
			Ag(i, j) = exponent;
			Ab(i, j) = exponent;
		}
		br(i) = params.YSamples[i].x;
		bg(i) = params.YSamples[i].y;
		bb(i) = params.YSamples[i].z;
	}

	Eigen::VectorXf rchan = Ar.jacobiSvd(Eigen::ComputeThinU | Eigen::ComputeThinV).solve(br);
	Eigen::VectorXf gchan = Ag.jacobiSvd(Eigen::ComputeThinU | Eigen::ComputeThinV).solve(bg);
	Eigen::VectorXf bchan = Ab.jacobiSvd(Eigen::ComputeThinU | Eigen::ComputeThinV).solve(bb);

	for(uint32 j = 0; j < params.NumSGs; ++j) {
		params.OutSGs[j].Amplitude.x = rchan[j];
		params.OutSGs[j].Amplitude.y = gchan[j];
		params.OutSGs[j].Amplitude.z = bchan[j];
	}
}

// Project sample onto SGs
void ProjectOntoSGs(const Float3& dir, const Float3& color, SG* outSGs, uint64 numSGs)
{
    for(uint64 i = 0; i < numSGs; ++i)
    {
        SG sg1;
        SG sg2;
        sg1.Amplitude = outSGs[i].Amplitude;
        sg1.Axis = outSGs[i].Axis;
        sg1.Sharpness = outSGs[i].Sharpness;
        sg2.Amplitude = color;
        sg2.Axis = Float3::Normalize(dir);

        if(Float3::Dot(dir, sg1.Axis) > 0.0f)
        {
            float dot = Float3::Dot(sg1.Axis, sg2.Axis);
            float factor = (dot - 1.0f) * sg1.Sharpness;
            float wgt = exp(factor);
            outSGs[i].Amplitude += sg2.Amplitude * wgt;
            Assert_(outSGs[i].Amplitude.x >= 0.0f);
            Assert_(outSGs[i].Amplitude.y >= 0.0f);
            Assert_(outSGs[i].Amplitude.z >= 0.0f);
        }
    }
}

// Do a projection of the colors onto the SG's
static void SolveProjection(SGSolveParam& params)
{
    Assert_(params.XSamples != nullptr);
    Assert_(params.YSamples != nullptr);

    // Project color samples onto the SGs
    for(uint32 i = 0; i < params.NumSamples; ++i)
        ProjectOntoSGs(params.XSamples[i], params.YSamples[i], params.OutSGs, params.NumSGs);

    // Weight the samples by the monte carlo factor for uniformly sampling the hemisphere
    float monteCarloFactor = ((2.0f * Pi) / params.NumSamples);
    for(uint32 i = 0; i < params.NumSGs; ++i)
        params.OutSGs[i].Amplitude *= monteCarloFactor;
}

// Accumulates a single sample for computing a set of SG's using a running average. This technique and the code it's based
// on was provided by Thomas Roughton in the following article: http://torust.me/rendering/irradiance-caching/spherical-gaussians/2018/09/21/spherical-gaussians.html
void SGRunningAverage(const Float3& dir, const Float3& color, SG* outSGs, uint64 numSGs, float sampleIdx, float* lobeWeights, bool nonNegative)
{
	float sampleWeightScale = 1.0f / (sampleIdx + 1);

    float sampleLobeWeights[AppSettings::MaxSGCount] = { };
    Float3 currentEstimate;

    for(uint64 lobeIdx = 0; lobeIdx < numSGs; ++lobeIdx)
    {
        float dotProduct = Float3::Dot(outSGs[lobeIdx].Axis, dir);
        float weight = exp(outSGs[lobeIdx].Sharpness * (dotProduct - 1.0f));
		currentEstimate += outSGs[lobeIdx].Amplitude * weight;

        sampleLobeWeights[lobeIdx] = weight;
    }

    for(uint64 lobeIdx = 0; lobeIdx < numSGs; ++lobeIdx)
    {
        float weight = sampleLobeWeights[lobeIdx];
        if(weight == 0.0f)
            continue;

		float sphericalIntegralGuess = weight * weight;

		lobeWeights[lobeIdx] += (sphericalIntegralGuess - lobeWeights[lobeIdx]) * sampleWeightScale;

		// Clamp the spherical integral estimate to at least the true value to reduce variance.
		float sphericalIntegral = std::max(lobeWeights[lobeIdx], outSGs[lobeIdx].BasisSqIntegralOverDomain);

		Float3 otherLobesContribution = currentEstimate - outSGs[lobeIdx].Amplitude * weight;
		Float3 newValue = (color - otherLobesContribution) * (weight / sphericalIntegral);

        outSGs[lobeIdx].Amplitude += (newValue - outSGs[lobeIdx].Amplitude) * sampleWeightScale;

        if(nonNegative)
        {
            outSGs[lobeIdx].Amplitude.x = Max(outSGs[lobeIdx].Amplitude.x, 0.0f);
            outSGs[lobeIdx].Amplitude.y = Max(outSGs[lobeIdx].Amplitude.y, 0.0f);
            outSGs[lobeIdx].Amplitude.z = Max(outSGs[lobeIdx].Amplitude.z, 0.0f);
        }
    }
}

static void SolveRunningAverage(SGSolveParam& params, bool nonNegative)
{
    Assert_(params.XSamples != nullptr);
    Assert_(params.YSamples != nullptr);

    float lobeWeights[AppSettings::MaxSGCount] = { };

    // Project color samples onto the SGs
    for(uint32 i = 0; i < params.NumSamples; ++i)
        SGRunningAverage(params.XSamples[i], params.YSamples[i], params.OutSGs, params.NumSGs, (float)i, lobeWeights, nonNegative);
}

// Solve the set of spherical gaussians based on input set of data
void SolveSGs(SGSolveParam& params)
{
    Assert_(params.NumSGs <= uint64(AppSettings::MaxSGCount));
    for(uint64 i = 0; i < params.NumSGs; ++i)
        params.OutSGs[i] = defaultInitialGuess[i];

    if(AppSettings::SolveMode == SolveModes::NNLS)
        SolveNNLS(params);
    else if(AppSettings::SolveMode == SolveModes::SVD)
        SolveSVD(params);
    else if(AppSettings::SolveMode == SolveModes::RunningAverage)
        SolveRunningAverage(params, false);
    else if(AppSettings::SolveMode == SolveModes::RunningAverageNN)
        SolveRunningAverage(params, true);
    else
        SolveProjection(params);
}