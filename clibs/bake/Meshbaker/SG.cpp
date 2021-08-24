//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================
#include "SG.h"
#include "Setting.h"
#include "Graphics/Sampling.h"

#pragma warning(push)
#pragma warning(disable : 4005)
#define EIGEN_MPL2_ONLY
#include "3rd/eigen/Eigen/Dense"
#include "3rd/eigen/Eigen/NNLS"

#include "3rd/eigen/unsupported/Eigen/NonLinearOptimization"
#include "3rd/eigen/unsupported/Eigen/NumericalDiff"
#pragma warning(pop)

static SG defaultInitialGuess[Setting::MaxSGCount];
static bool eigenInitialized = false;

// Generate uniform spherical gaussians on the sphere or hemisphere
void GenerateUniformSGs(SG* outSGs, uint64_t numSGs, SGDistribution distribution)
{
    const uint64_t N = distribution == SGDistribution::Hemispherical ? numSGs * 2 : numSGs;

    glm::vec3 means[Setting::MaxSGCount * 2];

    float inc = Pi * (3.0f - std::sqrt(5.0f));
    float off = 2.0f / N;
    for(uint64_t k = 0; k < N; ++k)
    {
        float y = k * off - 1.0f + (off / 2.0f);
        float r = std::sqrt(1.0f - y * y);
        float phi = k * inc;
        means[k] = glm::vec3(std::cos(phi) * r, std::sin(phi) * r, y);
    }

    uint64_t currSG = 0;
    for(uint64_t i = 0; i < N; ++i)
    {
        // For the sphere we always accept the sample point but for the hemisphere we only accept
        // sample points on the correct side of the hemisphere
        if(distribution == SGDistribution::Spherical || glm::dot(glm::vec3(means[i].z), glm::vec3(0.0f, 0.0f, 1.0f)) >= 0.0f)
        {
            SG sample;
            sample.Axis = glm::normalize(means[i]);
            outSGs[currSG++] = sample;
        }
    }

    float minDP = 1.0f;
    for(uint64_t i = 1; i < numSGs; ++i)
    {
        glm::vec3 h = glm::normalize(outSGs[i].Axis + outSGs[0].Axis);
        minDP = std::min(minDP, glm::dot(h, outSGs[0].Axis));
    }

    float sharpness = (std::log(0.65f) * numSGs) / (minDP - 1.0f);

    for(uint32_t i = 0; i < numSGs; ++i)
        outSGs[i].Sharpness = sharpness;

    const uint64_t sampleCount = 2048;
    glm::vec2 samples[sampleCount];
    Graphics::GenerateHammersleySamples2D(samples, sampleCount);

    for(uint32_t i = 0; i < numSGs; ++i)
        outSGs[i].BasisSqIntegralOverDomain = 0.0f;

    for(uint64_t i = 0; i < sampleCount; ++i)
    {
        glm::vec3 dir = distribution == SGDistribution::Hemispherical   ? Graphics::SampleDirectionHemisphere(samples[i].x, samples[i].y)
                                                                        : Graphics::SampleDirectionSphere(samples[i].x, samples[i].y);
        for(uint32_t j = 0; j < numSGs; ++j)
        {
            float weight = std::exp(outSGs[j].Sharpness * (glm::dot(dir, outSGs[j].Axis) - 1.0f));
            outSGs[j].BasisSqIntegralOverDomain += (weight * weight - outSGs[j].BasisSqIntegralOverDomain) / float(i + 1);
        }
    }
}

void InitializeSGSolver(uint64_t numSGs, SGDistribution distribution)
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
    assert(params.XSamples != nullptr);
    assert(params.YSamples != nullptr);

    // -- Linearly solve for the rgb channels one at a time
    Eigen::MatrixXf Ar, Ag, Ab;
    Ar.resize(params.NumSamples, int64_t(params.NumSGs));
    Ag.resize(params.NumSamples, int64_t(params.NumSGs));
    Ab.resize(params.NumSamples, int64_t(params.NumSGs));
    Eigen::VectorXf br(params.NumSamples);
    Eigen::VectorXf bg(params.NumSamples);
    Eigen::VectorXf bb(params.NumSamples);
    for(uint32_t i = 0; i < params.NumSamples; ++i)
    {
        // compute difference squared from actual observed data
        for(uint32_t j = 0; j < params.NumSGs; ++j)
        {
            float exponent = exp((glm::dot(params.XSamples[i], params.OutSGs[j].Axis) - 1.0f) *
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

    for(uint32_t j = 0; j < params.NumSGs; ++j)
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
	for(uint32_t i = 0; i < params.NumSamples; ++i)
	{
		// compute difference squared from actual observed data
		for(uint32_t j = 0; j < params.NumSGs; ++j)
		{
			float exponent = std::exp((glm::dot(params.XSamples[i], params.OutSGs[j].Axis) - 1.0f) *
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

	for(uint32_t j = 0; j < params.NumSGs; ++j) {
		params.OutSGs[j].Amplitude.x = rchan[j];
		params.OutSGs[j].Amplitude.y = gchan[j];
		params.OutSGs[j].Amplitude.z = bchan[j];
	}
}

// Project sample onto SGs
void ProjectOntoSGs(const glm::vec3& dir, const glm::vec3& color, SG* outSGs, uint64_t numSGs)
{
    for(uint64_t i = 0; i < numSGs; ++i)
    {
        SG sg1;
        SG sg2;
        sg1.Amplitude = outSGs[i].Amplitude;
        sg1.Axis = outSGs[i].Axis;
        sg1.Sharpness = outSGs[i].Sharpness;
        sg2.Amplitude = color;
        sg2.Axis = glm::normalize(dir);

        if(glm::dot(dir, sg1.Axis) > 0.0f)
        {
            float dot = glm::dot(sg1.Axis, sg2.Axis);
            float factor = (dot - 1.0f) * sg1.Sharpness;
            float wgt = exp(factor);
            outSGs[i].Amplitude += sg2.Amplitude * wgt;
            assert(outSGs[i].Amplitude.x >= 0.0f);
            assert(outSGs[i].Amplitude.y >= 0.0f);
            assert(outSGs[i].Amplitude.z >= 0.0f);
        }
    }
}

// Do a projection of the colors onto the SG's
static void SolveProjection(SGSolveParam& params)
{
    assert(params.XSamples != nullptr);
    assert(params.YSamples != nullptr);

    // Project color samples onto the SGs
    for(uint32_t i = 0; i < params.NumSamples; ++i)
        ProjectOntoSGs(params.XSamples[i], params.YSamples[i], params.OutSGs, params.NumSGs);

    // Weight the samples by the monte carlo factor for uniformly sampling the hemisphere
    float monteCarloFactor = ((2.0f * Pi) / params.NumSamples);
    for(uint32_t i = 0; i < params.NumSGs; ++i)
        params.OutSGs[i].Amplitude *= monteCarloFactor;
}

// Accumulates a single sample for computing a set of SG's using a running average. This technique and the code it's based
// on was provided by Thomas Roughton in the following article: http://torust.me/rendering/irradiance-caching/spherical-gaussians/2018/09/21/spherical-gaussians.html
void SGRunningAverage(const glm::vec3& dir, const glm::vec3& color, SG* outSGs, uint64_t numSGs, float sampleIdx, float* lobeWeights, bool nonNegative)
{
	float sampleWeightScale = 1.0f / (sampleIdx + 1);

    float sampleLobeWeights[Setting::MaxSGCount] = { };
    glm::vec3 currentEstimate;

    for(uint64_t lobeIdx = 0; lobeIdx < numSGs; ++lobeIdx)
    {
        float dotProduct = glm::dot(outSGs[lobeIdx].Axis, dir);
        float weight = exp(outSGs[lobeIdx].Sharpness * (dotProduct - 1.0f));
		currentEstimate += outSGs[lobeIdx].Amplitude * weight;

        sampleLobeWeights[lobeIdx] = weight;
    }

    for(uint64_t lobeIdx = 0; lobeIdx < numSGs; ++lobeIdx)
    {
        float weight = sampleLobeWeights[lobeIdx];
        if(weight == 0.0f)
            continue;

		float sphericalIntegralGuess = weight * weight;

		lobeWeights[lobeIdx] += (sphericalIntegralGuess - lobeWeights[lobeIdx]) * sampleWeightScale;

		// Clamp the spherical integral estimate to at least the true value to reduce variance.
		float sphericalIntegral = std::max(lobeWeights[lobeIdx], outSGs[lobeIdx].BasisSqIntegralOverDomain);

		glm::vec3 otherLobesContribution = currentEstimate - outSGs[lobeIdx].Amplitude * weight;
		glm::vec3 newValue = (color - otherLobesContribution) * (weight / sphericalIntegral);

        outSGs[lobeIdx].Amplitude += (newValue - outSGs[lobeIdx].Amplitude) * sampleWeightScale;

        if(nonNegative)
        {
            outSGs[lobeIdx].Amplitude = glm::max(outSGs[lobeIdx].Amplitude, glm::vec3(0.f));
        }
    }
}

static void SolveRunningAverage(SGSolveParam& params, bool nonNegative)
{
    assert(params.XSamples != nullptr);
    assert(params.YSamples != nullptr);

    float lobeWeights[Setting::MaxSGCount] = { };

    // Project color samples onto the SGs
    for(uint32_t i = 0; i < params.NumSamples; ++i)
        SGRunningAverage(params.XSamples[i], params.YSamples[i], params.OutSGs, params.NumSGs, (float)i, lobeWeights, nonNegative);
}

// Solve the set of spherical gaussians based on input set of data
void SolveSGs(SGSolveParam& params)
{
    assert(params.NumSGs <= uint64_t(Setting::MaxSGCount));
    for(uint64_t i = 0; i < params.NumSGs; ++i)
        params.OutSGs[i] = defaultInitialGuess[i];

    if(Setting::SolveMode == SolveModes::NNLS)
        SolveNNLS(params);
    else if(Setting::SolveMode == SolveModes::SVD)
        SolveSVD(params);
    else if(Setting::SolveMode == SolveModes::RunningAverage)
        SolveRunningAverage(params, false);
    else if(Setting::SolveMode == SolveModes::RunningAverageNN)
        SolveRunningAverage(params, true);
    else
        SolveProjection(params);
}