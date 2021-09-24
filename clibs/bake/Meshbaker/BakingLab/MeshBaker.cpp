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

#include "MeshBaker.h"

#include <Graphics/Model.h>
#include <Utility.h>
#include <Graphics/GraphicsTypes.h>
#include <Graphics/SH.h>
#include <Timer.h>
#include <App.h>
#include <Graphics/Textures.h>
#include <Graphics/BRDF.h>
#include <Graphics/Sampling.h>

#include "AppSettings.h"
#include "SG.h"
#include "PathTracer.h"

// Suppress vs2013: "new behavior: elements of array 'array' will be default initialized"
#pragma warning(disable : 4351)



#ifdef _DEBUG
#include <fstream>
static std::ofstream* off = nullptr;
static const char* fn = "d:/work/ant/log0.txt";
template<typename T>
static void Log(const T& arg) {
    if (off == nullptr) {
        off = new std::ofstream(fn);
    }

    *off << arg << std::endl;

    off->flush();
}

template<typename T, typename ...Args>
static void Log(const T& arg1, Args... args)
{
    if (off == nullptr) {
        off = new std::ofstream(fn);
    }

    *off << arg1;
    Log(args...);
}
#endif //_DEBUG

// Info about a gutter texel
struct GutterTexel
{
    Uint2 TexelPos;
    Uint2 NeighborPos;
};

// Returns the final monte-carlo weighting factor using the PDF of a cosine-weighted hemisphere
static float CosineWeightedMonteCarloFactor(uint64 numSamples)
{
    // Integrating cosine factor about the hemisphere gives you Pi, and the PDF
    // of a cosine-weighted hemisphere function is 1 / Pi.
    // So the final monte-carlo weighting factor is 1 / NumSamples
    return (1.0f / numSamples);
}

static float HemisphereMonteCarloFactor(uint64 numSamples)
{
    // The area of a unit hemisphere is 2 * Pi, so the PDF is 1 / (2 * Pi)
    return ((2.0f * Pi) / numSamples);
}

static float SphereMonteCarloFactor(uint64 numSamples)
{
    // The area of a unit hemisphere is 2 * Pi, so the PDF is 1 / (2 * Pi)
    return ((4.0f * Pi) / numSamples);
}

// == Baking ======================================================================================

// Bakes irradiance / Pi as 3 floats per texel
struct DiffuseBaker
{
    static const uint64 BasisCount = 1;

    uint64 NumSamples = 0;
    Float3 ResultSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;
        ResultSum = 0.0f;
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleCosineHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        ResultSum += sample;
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        float3 finalResult = ResultSum * CosineWeightedMonteCarloFactor(NumSamples);
        bakeOutput[0] = Float4(Float3::Clamp(finalResult, 0.0f, FP16Max), 1.0f);
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        const float lerpFactor = passIdx / (passIdx + 1.0f);
        Float3 newSample = ResultSum * CosineWeightedMonteCarloFactor(1);
        Float3 currValue = bakeOutput[0].To3D();
        currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
        bakeOutput[0] = Float4(Float3::Clamp(currValue, 0.0f, FP16Max), 1.0f);
    }
};

// Bakes irradiance based on Enlighten's directional approach, with 3 floats for color,
// 3 for lighting main direction information, and 1 float to ensure that the directional
// term evaluates to 1 when the surface normal aligns with normal used when baking.
//
// NOTE: A directional map can be encoded per RGB channel which puts the memory cost at
// the cost of L1 SH but at a worse quality. This implementation with a single directional
// map is provided as a cheap alternative at the expense of quality.
//
// Reference: https://static.docs.arm.com/100837/0308/enlighten_3-08_sdk_documentation__100837_0308_00_en.pdf
struct DirectionalBaker
{
    static const uint64 BasisCount = 2;

    uint64 NumSamples = 0;
    Float3 ResultSum;
    Float3 DirectionSum;
    float DirectionWeightSum;
    Float3 NormalSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;

        ResultSum = 0.0;
        DirectionSum = 0.0;
        DirectionWeightSum = 0.0;
        NormalSum = 0.0;
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        normal = Float3::Normalize(normal);

        const Float3 sampleDir = Float3::Normalize(sampleDirWS);

        ResultSum += sample;
        DirectionSum += sampleDir * ComputeLuminance(sample);
        DirectionWeightSum += ComputeLuminance(sample);
        NormalSum += normal;
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        Float3 finalColorResult = ResultSum * CosineWeightedMonteCarloFactor(NumSamples);

        Float3 finalDirection = Float3::Normalize(DirectionSum / std::max(DirectionWeightSum, 0.0001f));

        Float3 averageNormal = Float3::Normalize(NormalSum * CosineWeightedMonteCarloFactor(NumSamples));
        Float4 tau = Float4(averageNormal, 1.0f) * 0.5f;

        bakeOutput[0] = Float4(Float3::Clamp(finalColorResult, 0.0f, FP16Max), 1.0f);
        bakeOutput[1] = Float4(finalDirection * 0.5f + 0.5, std::max(Float4::Dot(tau, Float4(finalDirection, 1.0f)), 0.0001f));
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
    }
};

// Bakes irradiance based on Enlighten's RGB directional approach, with 3 floats for
// color, and 4 floats per RGB channel were 3 of the floats are the direction for the
// specific channel and the 4th float ensures that the directional term evaluates to 1
// when the surface normal aligns with normal used when baking.
//
// Reference: https://static.docs.arm.com/100837/0308/enlighten_3-08_sdk_documentation__100837_0308_00_en.pdf
struct DirectionalRGBBaker
{
    static const uint64 BasisCount = 4;

    uint64 NumSamples = 0;
    Float3 ResultSum;
    Float3 DirectionSum[3];
    Float3 DirectionWeightSum;
    Float3 NormalSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;

        ResultSum = 0.0;
        DirectionSum[0] = 0.0;
        DirectionSum[1] = 0.0;
        DirectionSum[2] = 0.0;
        DirectionWeightSum = 0.0;
        NormalSum = 0.0;
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        normal = Float3::Normalize(normal);

        const Float3 sampleDir = Float3::Normalize(sampleDirWS);

        ResultSum += sample;
        DirectionSum[0] += sampleDir * sample.x;
        DirectionSum[1] += sampleDir * sample.y;
        DirectionSum[2] += sampleDir * sample.z;
        DirectionWeightSum += sample;
        NormalSum += normal;
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        Float3 finalColorResult = ResultSum * CosineWeightedMonteCarloFactor(NumSamples);

        Float3 finalDirectionR = Float3::Normalize(DirectionSum[0] / std::max(DirectionWeightSum.x, 0.0001f));
        Float3 finalDirectionG = Float3::Normalize(DirectionSum[1] / std::max(DirectionWeightSum.y, 0.0001f));
        Float3 finalDirectionB = Float3::Normalize(DirectionSum[2] / std::max(DirectionWeightSum.z, 0.0001f));

        Float3 averageNormal = Float3::Normalize(NormalSum * CosineWeightedMonteCarloFactor(NumSamples));
        Float4 tau = Float4(averageNormal, 1.0f) * 0.5f;

        bakeOutput[0] = Float4(Float3::Clamp(finalColorResult, 0.0f, FP16Max), 1.0f);
        bakeOutput[1] = Float4(finalDirectionR * 0.5f + 0.5, std::max(Float4::Dot(tau, Float4(finalDirectionR, 1.0f)), 0.0001f));
        bakeOutput[2] = Float4(finalDirectionG * 0.5f + 0.5, std::max(Float4::Dot(tau, Float4(finalDirectionG, 1.0f)), 0.0001f));
        bakeOutput[3] = Float4(finalDirectionB * 0.5f + 0.5, std::max(Float4::Dot(tau, Float4(finalDirectionB, 1.0f)), 0.0001f));
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
    }
};

// Bakes irradiance projected onto the Half-Life 2 basis, with 9 floats per texel
struct HL2Baker
{
    static const uint64 BasisCount = 3;

    uint64 NumSamples = 0;
    Float3 ResultSum[3];

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;
        ResultSum[0] = ResultSum[1] = ResultSum[2] = 0.0f;
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        static const Float3 BasisDirs[BasisCount] =
        {
            Float3(-1.0f / std::sqrt(6.0f), -1.0f / std::sqrt(2.0f), 1.0f / std::sqrt(3.0f)),
            Float3(-1.0f / std::sqrt(6.0f), 1.0f / std::sqrt(2.0f), 1.0f / std::sqrt(3.0f)),
            Float3(std::sqrt(2.0f / 3.0f), 0.0f, 1.0f / std::sqrt(3.0f)),
        };
        for(uint64 i = 0; i < BasisCount; ++i)
            ResultSum[i] += sample * Float3::Dot(sampleDirTS, BasisDirs[i]);
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        for(uint64 i = 0; i < BasisCount; ++i)
        {
            Float3 result = ResultSum[i] * HemisphereMonteCarloFactor(NumSamples);
            bakeOutput[i] = Float4(Float3::Clamp(result, -FP16Max, FP16Max), 1.0f);
        }
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        const float lerpFactor = passIdx / (passIdx + 1.0f);
        for(uint64 i = 0; i < BasisCount; ++i)
        {
            Float3 newSample = ResultSum[i] * HemisphereMonteCarloFactor(1);
            Float3 currValue = bakeOutput[i].To3D();
            currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
            bakeOutput[i] = Float4(Float3::Clamp(currValue, -FP16Max, FP16Max), 1.0f);
        }
    }
};

// Bakes radiance projected onto L1 SH, with 12 floats per texel
struct SH4Baker
{
    static const uint64 BasisCount = 4;

    uint64 NumSamples = 0;
    SH4Color ResultSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;
        ResultSum = SH4Color();
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        const Float3 sampleDir = AppSettings::WorldSpaceBake ? sampleDirWS : sampleDirTS;
        ResultSum += ProjectOntoSH4Color(sampleDir, sample);
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        SH4Color result = ResultSum * HemisphereMonteCarloFactor(NumSamples);
        for(uint64 i = 0; i < BasisCount; ++i)
            bakeOutput[i] = Float4(Float3::Clamp(result.Coefficients[i], -FP16Max, FP16Max), 1.0f);
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        const float lerpFactor = passIdx / (passIdx + 1.0f);
        for(uint64 i = 0; i < BasisCount; ++i)
        {
            Float3 newSample = ResultSum.Coefficients[i] * HemisphereMonteCarloFactor(1);
            Float3 currValue = bakeOutput[i].To3D();
            currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
            bakeOutput[i] = Float4(Float3::Clamp(currValue, -FP16Max, FP16Max), 1.0f);
        }
    }
};

// Bakes radiance projected onto L2 SH, with 27 floats per texel
struct SH9Baker
{
    static const uint64 BasisCount = 9;

    uint64 NumSamples = 0;
    SH9Color ResultSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;
        ResultSum = SH9Color();
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        const Float3 sampleDir = AppSettings::WorldSpaceBake ? sampleDirWS : sampleDirTS;
        ResultSum += ProjectOntoSH9Color(sampleDir, sample);
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        SH9Color result = ResultSum * HemisphereMonteCarloFactor(NumSamples);
        for(uint64 i = 0; i < BasisCount; ++i)
            bakeOutput[i] = Float4(Float3::Clamp(result.Coefficients[i], -FP16Max, FP16Max), 1.0f);
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        const float lerpFactor = passIdx / (passIdx + 1.0f);
        for(uint64 i = 0; i < BasisCount; ++i)
        {
            Float3 newSample = ResultSum.Coefficients[i] * HemisphereMonteCarloFactor(1);
            Float3 currValue = bakeOutput[i].To3D();
            currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
            bakeOutput[i] = Float4(Float3::Clamp(currValue, -FP16Max, FP16Max), 1.0f);
        }
    }
};

// Bakes irradiance projected onto L1 H-basis, with 12 floats per texel
struct H4Baker
{
    static const uint64 BasisCount = 4;

    uint64 NumSamples = 0;
    SH9Color ResultSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;
        ResultSum = SH9Color();
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        ResultSum += ProjectOntoSH9Color(sampleDirTS, sample);
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        SH9Color shResult = ResultSum;
        shResult.ConvolveWithCosineKernel();
        H4Color result = ConvertToH4(shResult) * HemisphereMonteCarloFactor(NumSamples);
        for(uint64 i = 0; i < BasisCount; ++i)
            bakeOutput[i] = Float4(Float3::Clamp(result.Coefficients[i], -FP16Max, FP16Max), 1.0f);
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        SH9Color shResult = ResultSum;
        shResult.ConvolveWithCosineKernel();
        H4Color result = ConvertToH4(shResult) * HemisphereMonteCarloFactor(1);

        const float lerpFactor = passIdx / (passIdx + 1.0f);
        for(uint64 i = 0; i < BasisCount; ++i)
        {
            Float3 newSample = result.Coefficients[i];
            Float3 currValue = bakeOutput[i].To3D();
            currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
            bakeOutput[i] = Float4(Float3::Clamp(currValue, -FP16Max, FP16Max), 1.0f);
        }
    }
};

// Bakes irradiance projected onto L2 H-basis, with 18 floats per texel
struct H6Baker
{
    static const uint64 BasisCount = 6;

    uint64 NumSamples = 0;
    SH9Color ResultSum;

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        NumSamples = numSamples;
        ResultSum = SH9Color();
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        ResultSum += ProjectOntoSH9Color(sampleDirTS, sample);
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        SH9Color shResult = ResultSum;
        shResult.ConvolveWithCosineKernel();
        H6Color result = ConvertToH6(shResult) * HemisphereMonteCarloFactor(NumSamples);
        for(uint64 i = 0; i < BasisCount; ++i)
            bakeOutput[i] = Float4(Float3::Clamp(result.Coefficients[i], -FP16Max, FP16Max), 1.0f);
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        SH9Color shResult = ResultSum;
        shResult.ConvolveWithCosineKernel();
        H6Color result = ConvertToH6(shResult) * HemisphereMonteCarloFactor(1);

        const float lerpFactor = passIdx / (passIdx + 1.0f);
        for(uint64 i = 0; i < BasisCount; ++i)
        {
            Float3 newSample = result.Coefficients[i];
            Float3 currValue = bakeOutput[i].To3D();
            currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
            bakeOutput[i] = Float4(Float3::Clamp(currValue, -FP16Max, FP16Max), 1.0f);
        }
    }
};

// Bakes radiance into a set of SG lobes, which is computed using a solve or by
// using an ad-hoc projection. Bakes into SGCount * 3 floats.
template<uint64 SGCount> struct SGBaker
{
    static const uint64 BasisCount = SGCount;

    uint64 NumSamples = 0;
    uint64 CurrSampleIdx = 0;
    FixedArray<Float3> SampleDirs;
    FixedArray<Float3> Samples;
    SG ProjectedResult[SGCount];
    float RunningAverageWeights[SGCount] = { };

    void Init(uint64 numSamples, Float4 prevResult[BasisCount])
    {
        CurrSampleIdx = 0;
        NumSamples = numSamples;

        if(NumSamples != SampleDirs.Size())
            SampleDirs.Init(NumSamples);
        if(NumSamples != Samples.Size())
            Samples.Init(NumSamples);

        const SG* initialGuess = InitialGuess();
        for(uint64 i = 0; i < SGCount; ++i)
            ProjectedResult[i] = initialGuess[i];

        if(AppSettings::SolveMode == SolveModes::RunningAverage || AppSettings::SolveMode == SolveModes::RunningAverageNN)
        {
            for(uint64 i = 0; i < SGCount; ++i)
            {
                ProjectedResult[i].Amplitude = prevResult[i].To3D();
                RunningAverageWeights[i] = prevResult[i].w;
            }
        }
    }

    Float3 SampleDirection(Float2 samplePoint)
    {
        return SampleDirectionHemisphere(samplePoint.x, samplePoint.y);
    }

    void AddSample(Float3 sampleDirTS, uint64 sampleIdx, Float3 sample, Float3 sampleDirWS, Float3 normal)
    {
        const Float3 sampleDir = AppSettings::WorldSpaceBake ? sampleDirWS : sampleDirTS;
        SampleDirs[CurrSampleIdx] = sampleDir;
        Samples[CurrSampleIdx] = sample;
        ++CurrSampleIdx;

        if(AppSettings::SolveMode == SolveModes::RunningAverage)
            SGRunningAverage(sampleDir, sample, ProjectedResult, SGCount, (float)sampleIdx, RunningAverageWeights, false);
        else if(AppSettings::SolveMode == SolveModes::RunningAverageNN)
            SGRunningAverage(sampleDir, sample, ProjectedResult, SGCount, (float)sampleIdx, RunningAverageWeights, true);
        else
            ProjectOntoSGs(sampleDir, sample, ProjectedResult, SGCount);
    }

    void FinalResult(Float4 bakeOutput[BasisCount])
    {
        SG sgLobes[SGCount];

        SGSolveParam params;
        params.NumSGs = SGCount;
        params.OutSGs = sgLobes;
        params.XSamples = SampleDirs.Data();
        params.YSamples = Samples.Data();
        params.NumSamples = NumSamples;
        SolveSGs(params);

        for(uint64 i = 0; i < SGCount; ++i)
            bakeOutput[i] = Float4(Float3::Clamp(sgLobes[i].Amplitude, 0.0f, FP16Max), 1.0f);
    }

    void ProgressiveResult(Float4 bakeOutput[BasisCount], uint64 passIdx)
    {
        if(AppSettings::SolveMode == SolveModes::RunningAverage || AppSettings::SolveMode == SolveModes::RunningAverageNN)
        {
            for(uint64 i = 0; i < SGCount; ++i)
                bakeOutput[i] = Float4(Float3::Clamp(ProjectedResult[i].Amplitude, -FP16Max, FP16Max), RunningAverageWeights[i]);
        }
        else
        {
            const float lerpFactor = passIdx / (passIdx + 1.0f);
            for(uint64 i = 0; i < SGCount; ++i)
            {
                Float3 newSample = ProjectedResult[i].Amplitude * HemisphereMonteCarloFactor(1);
                Float3 currValue = bakeOutput[i].To3D();
                currValue = Lerp<Float3>(newSample, currValue, lerpFactor);
                bakeOutput[i] = Float4(Float3::Clamp(currValue, -FP16Max, FP16Max), 1.0f);
            }
        }
    }
};

typedef SGBaker<5> SG5Baker;
typedef SGBaker<6> SG6Baker;
typedef SGBaker<9> SG9Baker;
typedef SGBaker<12> SG12Baker;

const LightData* FindSunLight(const Lights *lights)
{
    for (auto &l : *lights){
        if (l.type == LightData::Directional){
            return &l;
        }
    }

    return nullptr;
}

// Data used by the baking threads
struct BakeThreadContext
{
    uint64 BakeTag = uint64(-1);
    const BVHData* SceneBVH = nullptr;
    const TextureData<Half4>* EnvMaps = nullptr;
    const std::vector<BakePoint>* BakePoints = nullptr;
    const Lights *lights = nullptr;
    const LightData *SunLight = nullptr;
    uint64 CurrNumBatches = 0;
    uint64 CurrLightMapSize = 0;
    BakeModes CurrBakeMode = BakeModes::Diffuse;
    SolveModes CurrSolveMode = SolveModes::NNLS;
    Random RandomGenerator;
    SampleModes CurrSampleMode = SampleModes::Random;
    uint64 CurrNumSamples = 0;
    const std::vector<IntegrationSamples>* Samples;
    FixedArray<Float4>* BakeOutput = nullptr;
    volatile int64* CurrBatch = nullptr;

    void Init(FixedArray<Float4>* bakeOutput, const std::vector<IntegrationSamples>* samples,
              volatile int64* currBatch, const MeshBaker* meshBaker, uint64 newTag)
    {
        if(BakeTag == uint64(-1))
            RandomGenerator.SeedWithRandomValue();

        BakeTag = newTag;
        lights = &meshBaker->input.lights;
        SunLight = FindSunLight(lights);
        SceneBVH = &meshBaker->sceneBVH;
        EnvMaps = meshBaker->input.EnvMapData;
        BakePoints = &meshBaker->bakePoints;

        CurrNumBatches = meshBaker->currNumBakeBatches;
        CurrLightMapSize = meshBaker->currLightMapSize;
        CurrBakeMode = meshBaker->currBakeMode;
        CurrSolveMode = meshBaker->currSolveMode;
        BakeOutput = bakeOutput;
        CurrBatch = currBatch;
        CurrSampleMode = BakeSetting::SampleMode;
        CurrNumSamples = BakeSetting::NumBakeSample;
        Samples = samples;
    }
};

// Runs a single iteration of the bake thread. If the bake mode supports progressive baking,
// then this function will add 1 path tracer sample to all texels within the bake group.
// Otherwise, it will completely bake a single texel within a bake group and flood fill
// its unbaked neighbors within the thread group.
template<typename TBaker> static bool BakeDriver(BakeThreadContext& context, TBaker& baker)
{
    if(context.CurrNumBatches == 0)
        return false;

    const uint64 batchIdx = InterlockedIncrement64(context.CurrBatch) - 1;
    if(batchIdx >= context.CurrNumBatches)
        return false;

    // Are we baking one sample per texel and progessively integrating, or are we going to
    // fully compute the final baked texel value and flood fill the neighbors?
    const bool progressiveintegration = s_BakeSetting.SupportsProgressiveIntegration(context.CurrBakeMode, context.CurrSolveMode);

    // Figure out which 8x8 group we're working on
    const uint64 numGroupsX = (context.CurrLightMapSize + (BakeSetting::BakeGroupSizeX - 1)) / BakeSetting::BakeGroupSizeX;
    const uint64 numGroupsY = (context.CurrLightMapSize + (BakeSetting::BakeGroupSizeY - 1)) / BakeSetting::BakeGroupSizeY;
    const uint64 numBakeGroups = numGroupsX * numGroupsY;

    const uint64 groupIdx = batchIdx % numBakeGroups;
    const uint64 groupIdxX = groupIdx % numGroupsX;
    const uint64 groupIdxY = groupIdx / numGroupsX;

    const uint64 sqrtNumSamples = context.CurrNumSamples;
    const uint64 numSamplesPerTexel = sqrtNumSamples * sqrtNumSamples;

    Random& random = context.RandomGenerator;

    const bool addAreaLight = false;//AppSettings::EnableAreaLight && AppSettings::BakeDirectAreaLight;

    // Get the set of integration samples to use, which is tiled across threads
    const uint64 numThreads = context.Samples->size();
    const IntegrationSamples& integrationSamples = (*context.Samples)[groupIdx % numThreads];

    PathTracerParams params;
    // params.EnableDirectAreaLight = false;
    // params.EnableDirectSun = false;
    params.SunLight = context.SunLight;
    params.lights = context.lights;
    params.EnableDiffuse = true;
    params.EnableSpecular = false;
    params.EnableBounceSpecular = false;
    params.MaxPathLength                = BakeSetting::MaxBakePathLength;
    params.RussianRouletteDepth         = BakeSetting::BakeRussianRouletteDepth;
    params.RussianRouletteProbability   = BakeSetting::BakeRussianRouletteProbability;
    params.RayLen = FLT_MAX;
    params.SceneBVH = context.SceneBVH;
    params.SkyCache = &context.SkyCache;
    params.EnvMaps = context.EnvMaps;

    if(progressiveintegration)
    {
        const uint64 sampleIdx = batchIdx / numBakeGroups;

        // Loop over all texels in the 8x8 group, and compute 1 sample for each
        for(uint64 groupTexelIdxX = 0; groupTexelIdxX < BakeSetting::BakeGroupSizeX; ++groupTexelIdxX)
        {
            for(uint64 groupTexelIdxY = 0; groupTexelIdxY < BakeSetting::BakeGroupSizeY; ++groupTexelIdxY)
            {
                const uint64 groupTexelIdx = groupTexelIdxY * BakeSetting::BakeGroupSizeX + groupTexelIdxX;

                // Compute the absolute indices of the texel we're going to work on
                const uint64 texelIdxX = groupIdxX * BakeSetting::BakeGroupSizeX + groupTexelIdxX;
                const uint64 texelIdxY = groupIdxY * BakeSetting::BakeGroupSizeY + groupTexelIdxY;
                const uint64 texelIdx = texelIdxY * context.CurrLightMapSize + texelIdxX;
                if(texelIdxX >= context.CurrLightMapSize || texelIdxY >= context.CurrLightMapSize)
                    continue;

                // Skip if the texel is empty
                const std::vector<BakePoint>& bakePoints = *context.BakePoints;
                const BakePoint& bakePoint = bakePoints[texelIdx];
                if(bakePoint.Coverage == 0 || bakePoint.Coverage == 0xFFFFFFFF)
                    continue;

                Float4 texelResults[TBaker::BasisCount];
                if(sampleIdx > 0)
                {
                    for(uint64 basisIdx = 0; basisIdx < TBaker::BasisCount; ++basisIdx)
                        texelResults[basisIdx] = context.BakeOutput[basisIdx][texelIdx];
                }

                // The baker only accumulates one sample per pixel in progressive rendering.
                baker.Init(1, texelResults);

                IntegrationSampleSet sampleSet;
                sampleSet.Init(integrationSamples, groupTexelIdx, sampleIdx);

                Float3x3 tangentFrame;
                tangentFrame.SetXBasis(bakePoint.Tangent);
                tangentFrame.SetYBasis(bakePoint.Bitangent);
                tangentFrame.SetZBasis(bakePoint.Normal);

                // Create a random ray direction in tangent space, then convert to world space
                Float3 rayStart = bakePoint.Position;
                Float3 rayDirTS = baker.SampleDirection(sampleSet.Pixel());
                Float3 rayDirWS = Float3::Transform(rayDirTS, tangentFrame);
                rayDirWS = Float3::Normalize(rayDirWS);

                Float3 sampleResult = 0.0f;

                Float2 directAreaLightSample = sampleSet.Lens();
                if(addAreaLight && directAreaLightSample.x >= 0.5f)
                {
                    Float3 areaLightIrradiance;
                    sampleResult = SampleAreaLight(bakePoint.Position, bakePoint.Normal, context.SceneBVH->Scene,
                                                   1.0f, 0.0f, false, 0.0f, 1.0f, sampleSet.Lens().x,
                                                   sampleSet.Lens().y, areaLightIrradiance, rayDirWS);
                    rayDirTS = Float3::Transform(rayDirWS, Float3x3::Transpose(tangentFrame));
                }
                else
                {
                    params.RayDir = rayDirWS;
                    params.RayStart = rayStart + 0.1f * rayDirWS;
                    params.RayLen = FLT_MAX;
                    params.SampleSet = &sampleSet;

                    float illuminance = 0.0f;
                    bool hitSky = false;
                    sampleResult = PathTrace(params, random, illuminance, hitSky);

                    const bool BakeDirectSunLight = true;
                    if(BakeDirectSunLight)
                    {
                        Float3 sunLightIrradiance;
                        sampleResult += SampleSunLight2(bakePoint.Position, bakePoint.Normal, context.SceneBVH->Scene,
                            1.0f, 0.0f, false, 0.0f, 1.0f, sampleSet.Lens().x,
                            sampleSet.Lens().y,  params.SunLight, sunLightIrradiance);
                    }
                }

                // Account for equally distributing our samples among the area light and the rest of the environment
                if(addAreaLight)
                    sampleResult *= 2.0f;

				if (!isfinite(sampleResult.x) || !isfinite(sampleResult.y) || !isfinite(sampleResult.z))
					sampleResult = 0.0;

                baker.AddSample(rayDirTS, sampleIdx, sampleResult, rayDirWS, bakePoint.Normal);

                baker.ProgressiveResult(texelResults, sampleIdx);

                for(uint64 basisIdx = 0; basisIdx < TBaker::BasisCount; ++basisIdx){
                    context.BakeOutput[basisIdx][texelIdx] = texelResults[basisIdx];
                }
                    
            }
        }
    }
    else
    {
        Float4 texelResults[TBaker::BasisCount];
        baker.Init(numSamplesPerTexel, texelResults);

        // Figure out the texel within the group that we're working on (we do 64 passes per group, each one a different texel)
        const uint64 groupTexelIdx =  batchIdx / numBakeGroups;
        const uint64 groupTexelIdxX = groupTexelIdx % BakeSetting::BakeGroupSizeX;
        const uint64 groupTexelIdxY = groupTexelIdx / BakeSetting::BakeGroupSizeX;

        const uint64 texelIdxX = groupIdxX * BakeSetting::BakeGroupSizeX + groupTexelIdxX;
        const uint64 texelIdxY = groupIdxY * BakeSetting::BakeGroupSizeY + groupTexelIdxY;
        const uint64 texelIdx = texelIdxY * context.CurrLightMapSize + texelIdxX;
        if(texelIdxX >= context.CurrLightMapSize || texelIdxY >= context.CurrLightMapSize)
            return true;

        // Skip if the texel is empty
        const std::vector<BakePoint>& bakePoints = *context.BakePoints;
        const BakePoint& bakePoint = bakePoints[texelIdx];
        if(bakePoint.Coverage == 0 || bakePoint.Coverage == 0xFFFFFFFF)
            return true;

        Float3x3 tangentFrame;
        tangentFrame.SetXBasis(bakePoint.Tangent);
        tangentFrame.SetYBasis(bakePoint.Bitangent);
        tangentFrame.SetZBasis(bakePoint.Normal);

        for(uint64 sampleIdx = 0; sampleIdx < numSamplesPerTexel; ++sampleIdx)
        {
            IntegrationSampleSet sampleSet;
            sampleSet.Init(integrationSamples, groupTexelIdx, sampleIdx);

            // Create a random ray direction in tangent space, then convert to world space
            Float3 rayStart = bakePoint.Position;
            Float3 rayDirTS = baker.SampleDirection(sampleSet.Pixel());
            Float3 rayDirWS = Float3::Transform(rayDirTS, tangentFrame);
            rayDirWS = Float3::Normalize(rayDirWS);

            Float3 sampleResult;

            Float2 directAreaLightSample = sampleSet.Lens();
            if(addAreaLight && directAreaLightSample.x >= 0.5f)
            {
                Float3 areaLightIrradiance;
                sampleResult += SampleAreaLight(bakePoint.Position, bakePoint.Normal, context.SceneBVH->Scene,
                                                1.0f, 0.0f, false, 0.0f, 1.0f, sampleSet.Lens().x,
                                                sampleSet.Lens().y, areaLightIrradiance, rayDirWS);
                rayDirTS = Float3::Transform(rayDirWS, Float3x3::Transpose(tangentFrame));
            }
            else
            {
                params.RayDir = rayDirWS;
                params.RayStart = rayStart + 0.1f * rayDirWS;
                params.RayLen = FLT_MAX;
                params.SampleSet = &sampleSet;

                float illuminance = 0.0f;
                bool hitSky = false;
                sampleResult = PathTrace(params, random, illuminance, hitSky);

                const bool BakeDirectSunLight = true;
                if(BakeDirectSunLight)
                {
                    Float3 sunLightIrradiance;
                    sampleResult += SampleSunLight2(bakePoint.Position, bakePoint.Normal, context.SceneBVH->Scene,
                        1.0f, 0.0f, false, 0.0f, 1.0f, sampleSet.Lens().x,
                        sampleSet.Lens().y,  params.SunLight, sunLightIrradiance);
                }
            }

            // Account for equally distributing our samples among the area light and the rest of the environment
            if(addAreaLight)
                sampleResult *= 2.0f;

			if (!isfinite(sampleResult.x) || !isfinite(sampleResult.y) || !isfinite(sampleResult.z))
				sampleResult = 0.0;

            baker.AddSample(rayDirTS, sampleIdx, sampleResult, rayDirWS, bakePoint.Normal);
        }

        baker.FinalResult(texelResults);
        for(uint64 basisIdx = 0; basisIdx < TBaker::BasisCount; ++basisIdx)
            context.BakeOutput[basisIdx][texelIdx] = texelResults[basisIdx];

        // Temporarily fill in the rest of the texels in the group
        for(uint64 i = groupTexelIdx; i < BakeSetting::BakeGroupSize; ++i)
        {
            const uint64 offsetX = i % BakeSetting::BakeGroupSizeX;
            const uint64 offsetY = i / BakeSetting::BakeGroupSizeX;
            const uint64 neighborX = groupIdxX * BakeSetting::BakeGroupSizeX + offsetX;
            const uint64 neighborY = groupIdxY * BakeSetting::BakeGroupSizeY + offsetY;
            if(neighborX >= context.CurrLightMapSize || neighborY >= context.CurrLightMapSize)
                continue;

            uint64 neighborTexelIdx = neighborY * context.CurrLightMapSize + neighborX;
            for(uint64 basisIdx = 0; basisIdx < TBaker::BasisCount; ++basisIdx)
                context.BakeOutput[basisIdx][neighborTexelIdx] = texelResults[basisIdx];
        }
    }

    return true;
}

// Data passed to the bake thread entry point
struct BakeThreadData
{
    FixedArray<Float4>* BakeOutput = nullptr;
    const std::vector<IntegrationSamples>* Samples = nullptr;
    volatile int64* CurrBatch = nullptr;
    const MeshBaker* Baker = nullptr;
};

// Entry point for a bake thread
template<typename TBaker> uint32 __stdcall BakeThread(void* data)
{
    BakeThreadData* threadData = reinterpret_cast<BakeThreadData*>(data);
    const MeshBaker* meshBaker = threadData->Baker;

    BakeThreadContext context;
    TBaker baker;

    while(meshBaker->killBakeThreads == false)
    {
        const uint64 currTag = meshBaker->bakeTag;
        if(context.BakeTag != currTag)
            context.Init(threadData->BakeOutput, threadData->Samples,
                         threadData->CurrBatch, threadData->Baker, currTag);

        if(BakeDriver<TBaker>(context, baker) == false)
            Sleep(5);
    }

    return 0;
}


// Builds a BVH tree for an entire model/scene
static void BuildBVH(const Model& model, BVHData& bvhData, ID3D11Device* d3dDevice, RTCDevice device)
{
    if(bvhData.Scene != nullptr)
    {
        rtcDeleteScene(bvhData.Scene);
        bvhData.Scene = nullptr;
    }
    bvhData.Scene = rtcDeviceNewScene(device, RTC_SCENE_DYNAMIC, RTC_INTERSECT1);
    bvhData.Device = device;

    // Count the total number of vertices and triangles
    uint32 totalNumVertices = 0;
    uint32 totalNumTriangles = 0;
    for(uint64 i = 0; i < model.Meshes().size(); ++i)
    {
        const Mesh& mesh = model.Meshes()[i];
        Assert_(mesh.VertexStride() == sizeof(Vertex));
        totalNumVertices += mesh.NumVertices();
        totalNumTriangles += mesh.NumIndices() / 3;
    }

    bvhData.Triangles.resize(totalNumTriangles);
    bvhData.Vertices.resize(totalNumVertices);
    bvhData.MaterialIndices.resize(totalNumTriangles);
    std::vector<Float4> vertices(totalNumVertices);

    uint32 vtxOffset = 0;
    uint32 triOffset = 0;

    // Add the data for each mesh
    for(uint64 meshIdx = 0; meshIdx < model.Meshes().size(); ++meshIdx)
    {
        const Mesh& mesh = model.Meshes()[meshIdx];
        const Vertex* vertexData = reinterpret_cast<const Vertex*>(mesh.Vertices());
        const uint8* indexData = mesh.Indices();
        const uint32 numVertices = mesh.NumVertices();
        const uint32 numIndices = mesh.NumIndices();
        const uint32 indexSize = mesh.IndexSize();
        const uint32 vertexStride = mesh.VertexStride();

        // Prepare the triangles
        const uint32 numTriangles = numIndices / 3;
        for(uint64 partIdx = 0; partIdx < mesh.MeshParts().size(); ++partIdx)
        {
            const MeshPart& meshPart = mesh.MeshParts()[partIdx];
            const uint32 startTriangle = meshPart.IndexStart / 3;
            const uint32 endTriangle = (meshPart.IndexStart + meshPart.IndexCount) / 3;
            for(uint32 i = startTriangle; i < endTriangle; ++i)
            {
                const uint32 idx0 = GetIndex(indexData, i * 3 + 0, indexSize) + vtxOffset;
                const uint32 idx1 = GetIndex(indexData, i * 3 + 1, indexSize) + vtxOffset;
                const uint32 idx2 = GetIndex(indexData, i * 3 + 2, indexSize) + vtxOffset;

                bvhData.Triangles[i + triOffset] = Uint3(idx0, idx1, idx2);
                bvhData.MaterialIndices[i + triOffset] = meshPart.MaterialIdx;
            }
        }

        // Prepare the vertices
        for(uint32 i = 0; i < numVertices; ++i)
        {
            const Float3& position = vertexData[i].Position;
            vertices[i + vtxOffset] = Float4(position, 0.0f);
            bvhData.Vertices[i + vtxOffset] = vertexData[i];
        }

        triOffset += numTriangles;
        vtxOffset += numVertices;
    }

    uint32 geoID = rtcNewTriangleMesh(bvhData.Scene, RTC_GEOMETRY_STATIC, totalNumTriangles, totalNumVertices);

    Float4* meshVerts = reinterpret_cast<Float4*>(rtcMapBuffer(bvhData.Scene, geoID, RTC_VERTEX_BUFFER));
    memcpy(meshVerts, vertices.data(), totalNumVertices * sizeof(Float4));
    rtcUnmapBuffer(bvhData.Scene, geoID, RTC_VERTEX_BUFFER);

    Uint3* meshTriangles = reinterpret_cast<Uint3*>(rtcMapBuffer(bvhData.Scene, geoID, RTC_INDEX_BUFFER));
    memcpy(meshTriangles, bvhData.Triangles.data(), totalNumTriangles * sizeof(Uint3));
    rtcUnmapBuffer(bvhData.Scene, geoID, RTC_INDEX_BUFFER);

    rtcCommit(bvhData.Scene);

    RTCError embreeError = rtcDeviceGetError(device);
    Assert_(embreeError == RTC_NO_ERROR);
    if(embreeError != RTC_NO_ERROR)
        throw Exception(L"Failed to build embree scene!");

    // Load the material texture data
    const uint64 numMaterials = model.Materials().size();
    bvhData.MaterialDiffuseMaps.resize(numMaterials);
    bvhData.MaterialNormalMaps.resize(numMaterials);
    bvhData.MaterialRoughnessMaps.resize(numMaterials);
    bvhData.MaterialMetallicMaps.resize(numMaterials);

    for(uint64 i = 0; i < numMaterials; ++i)
    {
        const MeshMaterial& material = model.Materials()[i];
        GetTextureData(d3dDevice, material.DiffuseMap, bvhData.MaterialDiffuseMaps[i]);
        GetTextureData(d3dDevice, material.NormalMap, bvhData.MaterialNormalMaps[i]);
        GetTextureData(d3dDevice, material.RoughnessMap, bvhData.MaterialRoughnessMaps[i]);
        GetTextureData(d3dDevice, material.MetallicMap, bvhData.MaterialMetallicMaps[i]);
    }
}

static void drawmesh(ID3D11DeviceContextPtr context, ID3D11Device* device, VertexShaderPtr vs, ConstantBuffer<uint32> &constantBuffer, 
    const Mesh& mesh, uint32 vertexOffset)
{
    ID3D11InputLayoutPtr inputLayout;
    DXCall(device->CreateInputLayout(mesh.InputElements(), mesh.NumInputElements(),
                                    vs->ByteCode->GetBufferPointer(),
                                    vs->ByteCode->GetBufferSize(), &inputLayout));
    context->IASetInputLayout(inputLayout);

    ID3D11Buffer* vertexBuffers[1] = { mesh.VertexBuffer() };
    UINT vertexStrides[1] = { mesh.VertexStride() };
    UINT offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
    context->IASetIndexBuffer(mesh.IndexBuffer(), mesh.IndexBufferFormat(), 0);
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    constantBuffer.Data = vertexOffset;
    constantBuffer.ApplyChanges(context);

    context->DrawIndexed(mesh.NumIndices(), 0, 0);
};

// Computes lightmap sample points and gutter texels
static void ExtractBakePoints(const BakeInputData& bakeInput, std::vector<BakePoint>& bakePoints,
                              std::vector<GutterTexel>& gutterTexels, uint32 bakeMeshIdx)
{
    const uint32 LightMapSize = AppSettings::LightMapResolution;
    const uint64 NumTexels = LightMapSize * LightMapSize;

    bakePoints.clear();
    bakePoints.resize(NumTexels);
    gutterTexels.clear();

    Timer timer;
    PrintString("Extracting light map sample points...");

    ID3D11Device* device = bakeInput.Device;
    ID3D11DeviceContextPtr context;
    device->GetImmediateContext(&context);

    // Rasterize the mesh to the lightmap in UV space
    const uint32 NumTargets = 5;
    const DXGI_FORMAT RTFormats[NumTargets] =
    {
        DXGI_FORMAT_R32G32B32A32_FLOAT,
        DXGI_FORMAT_R32G32B32A32_FLOAT,
        DXGI_FORMAT_R32G32B32A32_FLOAT,
        DXGI_FORMAT_R32G32B32A32_FLOAT,
        DXGI_FORMAT_R32_UINT,
    };

    RenderTarget2D targets[NumTargets];
    RenderTarget2D msaaTargets[NumTargets];
    for(uint64 i = 0; i < NumTargets; ++i)
    {
        targets[i].Initialize(bakeInput.Device, LightMapSize, LightMapSize, RTFormats[i]);
        msaaTargets[i].Initialize(bakeInput.Device, LightMapSize, LightMapSize, RTFormats[i], 1, 8, 0);
    }

    ID3D11RenderTargetView* rtViews[NumTargets];
    for(uint64 i = 0; i < NumTargets; ++i)
        rtViews[i] = msaaTargets[i].RTView;

    context->OMSetRenderTargets(NumTargets, rtViews, nullptr);

    float clearColor[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
    for(uint64 i = 0; i < NumTargets; ++i)
        context->ClearRenderTargetView(rtViews[i], clearColor);

    VertexShaderPtr vs = CompileVSFromFile(device, (BakingLabDir() + L"LightMapRasterization.hlsl").c_str());
    PixelShaderPtr ps = CompilePSFromFile(device,  (BakingLabDir() + L"LightMapRasterization.hlsl").c_str());

    context->VSSetShader(vs, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->PSSetShader(ps, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);
    context->DSSetShader(nullptr, nullptr, 0);

    RasterizerStates rasterizerStates;
    rasterizerStates.Initialize(device);
    context->RSSetState(rasterizerStates.NoCull());

    BlendStates blendStates;
    blendStates.Initialize(device);
    float blendFactor[4] = { 1.0f, 1.0f, 1.0f, 1.0f };
    context->OMSetBlendState(blendStates.BlendDisabled(), blendFactor, 0xFFFFFFFF);

    DepthStencilStates dsStates;
    dsStates.Initialize(device);
    context->OMSetDepthStencilState(dsStates.DepthDisabled(), 0);

    D3D11_VIEWPORT viewport;
    viewport.Width = float(LightMapSize);
    viewport.Height = float(LightMapSize);
    viewport.TopLeftX = 0.0f;
    viewport.TopLeftY = 0.0f;
    viewport.MinDepth = 0.0f;
    viewport.MaxDepth = 1.0f;
    context->RSSetViewports(1, &viewport);

    ConstantBuffer<uint32> constantBuffer;
    constantBuffer.Initialize(device);
    constantBuffer.SetPS(context, 0);

    uint32 vertexOffset = 0;

    const Model& model = *bakeInput.SceneModel;
    const std::vector<Mesh>& meshes = model.Meshes();


    if (bakeMeshIdx != UINT32_MAX){
        const Mesh& mesh = meshes[bakeMeshIdx];
        drawmesh(context, device, vs, constantBuffer, mesh, vertexOffset);
    } else {
        for(uint64 meshIdx = 0; meshIdx < meshes.size(); ++meshIdx)
        {
            const Mesh& mesh = meshes[meshIdx];
            drawmesh(context, device, vs, constantBuffer, mesh, vertexOffset);
            vertexOffset += mesh.NumVertices();
        }
    }

    // Resolve the targets
    VertexShaderPtr resolveVS = CompileVSFromFile(device, (BakingLabDir() + L"LightMapRasterization.hlsl").c_str(), "ResolveVS");
    PixelShaderPtr resolvePS = CompilePSFromFile(device,  (BakingLabDir() + L"LightMapRasterization.hlsl").c_str(), "ResolvePS");
    context->VSSetShader(resolveVS, nullptr, 0);
    context->PSSetShader(resolvePS, nullptr, 0);

    for(uint64 i = 0; i < NumTargets; ++i)
        rtViews[i] = targets[i].RTView;
    context->OMSetRenderTargets(NumTargets, rtViews, nullptr);

    context->IASetInputLayout(nullptr);
    context->IASetIndexBuffer(nullptr, DXGI_FORMAT_R16_UINT, 0);
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    ID3D11Buffer* vertexBuffers[1] = { nullptr };
    UINT vertexStrides[1] = { 0 };
    UINT offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);

    ID3D11ShaderResourceView* srViews[NumTargets];
    for(uint64 i = 0; i < NumTargets; ++i)
        srViews[i] = msaaTargets[i].SRView;
    context->PSSetShaderResources(0, NumTargets, srViews);

    context->Draw(3, 0);

    context->VSSetShader(nullptr, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->PSSetShader(nullptr, nullptr, 0);

    for(uint64 i = 0; i < NumTargets; ++i)
    {
        rtViews[i] = nullptr;
        srViews[i] = nullptr;
    }

    context->OMSetRenderTargets(NumTargets, rtViews, nullptr);
    context->PSSetShaderResources(0, NumTargets, srViews);

    // Read back the results, and extract the sample points
    StagingTexture2D stagingTextures[NumTargets];
    uint32 pitches[5] = { 0 };
    const uint8* textureData[5] = { nullptr };
    for(uint64 i = 0; i < NumTargets; ++i)
    {
        stagingTextures[i].Initialize(device, LightMapSize, LightMapSize, RTFormats[i]);
        context->CopyResource(stagingTextures[i].Texture, targets[i].Texture);
        textureData[i] = reinterpret_cast<uint8*>(stagingTextures[i].Map(context, 0, pitches[i]));
    }

    for(uint32 y = 0; y < LightMapSize; ++y)
    {
        const Float4* positions = reinterpret_cast<const Float4*>(textureData[0] + y * pitches[0]);
        const Float4* normals = reinterpret_cast<const Float4*>(textureData[1] + y * pitches[1]);
        const Float4* tangents = reinterpret_cast<const Float4*>(textureData[2] + y * pitches[2]);
        const Float4* bitangents = reinterpret_cast<const Float4*>(textureData[3] + y * pitches[3]);
        const uint32* coverage = reinterpret_cast<const uint32*>(textureData[4] + y * pitches[4]);
        for(uint32 x = 0; x < LightMapSize; ++x)
        {
            const uint64 pointIdx = y * LightMapSize + x;
            BakePoint& bakePoint = bakePoints[pointIdx];

            if(coverage[x] != 0)
            {
                // Active texel, extract the relevent data from the rasterization result
                bakePoint.Position = positions[x].To3D();
                bakePoint.Normal = normals[x].To3D();
                bakePoint.Tangent = tangents[x].To3D();
                bakePoint.Bitangent = bitangents[x].To3D();
                bakePoint.Size = Float2(positions[x].w, normals[x].w);
                bakePoint.Coverage = coverage[x];
                bakePoint.TexelPos = Uint2(x, y);
                bakePoints.push_back(bakePoint);
            }
            else
            {
                // Check if this is a gutter texel that needs to replicate its value from a neighbor
                GutterTexel gutterTexel;
                gutterTexel.TexelPos = Uint2(x, y);
                int32 currDist = 0;
                bool foundNeighbor = false;

                // Empty texel, look for nearby active texels to see if we're a gutter texel
                for(int32 ny = -1; ny <= 1; ++ny)
                {
                    int32 neighborY = y + ny;
                    if(neighborY < 0 || neighborY >= int32(LightMapSize))
                        continue;

                    for(int32 nx = -1; nx <= 1; ++nx)
                    {
                        if(nx == 0 && ny == 0)
                            continue;

                        int32 neighborX = x + nx;
                        if(neighborX < 0 || neighborX >= int32(LightMapSize))
                            continue;

                        int32 dist = std::abs(nx) + std::abs(ny);
                        if(foundNeighbor && dist >= currDist)
                            continue;

                        int32 offset = neighborY * pitches[4] + neighborX * sizeof(uint32);
                        const uint32 neighborCoverage = *reinterpret_cast<const uint32*>(textureData[4] + offset);
                        if(neighborCoverage != 0)
                        {
                            gutterTexel.NeighborPos = Uint2(neighborX, neighborY);
                            foundNeighbor = true;
                            currDist = dist;
                        }
                    }
                }

                if(foundNeighbor)
                {
                    // Mark it as a gutter texel
                    bakePoint.Coverage = 0xFFFFFFFF;
                    bakePoint.TexelPos = gutterTexel.NeighborPos;
                    gutterTexels.push_back(gutterTexel);
                }
            }
        }
    }

    for(uint64 i = 0; i < NumTargets; ++i)
        stagingTextures[i].Unmap(context, 0);


    timer.Update();
    PrintString("Finished! (%fs)", timer.DeltaSecondsF());
}

// == MeshBaker ===================================================================================

static uint64 GetNumThreads()
{
    return 1;
    SYSTEM_INFO sysInfo;
    GetSystemInfo(&sysInfo);
    return std::max<uint64>(1, sysInfo.dwNumberOfProcessors - 1);
}

MeshBaker::MeshBaker()
{
}

MeshBaker::~MeshBaker()
{
    Shutdown();
}

void MeshBaker::Initialize(const BakeInputData& inputData)
{
    input = inputData;
    for(uint64 i = 0; i < AppSettings::NumCubeMaps; ++i)
        GetTextureData(input.Device, input.EnvMaps[i], input.EnvMapData[i]);

     // Init embree
    rtcDevice = rtcNewDevice();
    RTCError embreeError = rtcDeviceGetError(rtcDevice);
    if(embreeError == RTC_UNSUPPORTED_CPU)
        throw Exception(L"Your CPU does not meet the minimum requirements for embree");
    else if(embreeError != RTC_NO_ERROR)
        throw Exception(L"Failed to initialize embree!");

    // Build the BVHs
    BuildBVH(*input.SceneModel, sceneBVH, input.Device, rtcDevice);

    bakeSampleMode = AppSettings::BakeSampleMode;
    numBakeSamples = AppSettings::NumBakeSamples;

    numThreads = GetNumThreads();
    renderSamples.resize(numThreads);
    bakeSamples.resize(numThreads);

    for(uint64 i = 0; i < numThreads; ++i)
    {
        GenerateIntegrationSamples(bakeSamples[i], numBakeSamples, BakeGroupSize, 1,
                                   bakeSampleMode, NumIntegrationTypes, rng);
    }

    initialized = true;
}

void MeshBaker::Shutdown()
{
    if(initialized == false)
        return;

    KillBakeThreads();
    KillRenderThreads();

    // Shutdown embree
    sceneBVH = BVHData();
    rtcDeleteDevice(rtcDevice);
    rtcDevice = nullptr;
}

MeshBakerStatus MeshBaker::Update(const Camera& camera, uint32 screenWidth, uint32 screenHeight,
                                  ID3D11DeviceContext* deviceContext, 
                                  const Model* currentModel)
{
    Assert_(initialized);
    if(AppSettings::BakeSampleMode != bakeSampleMode || AppSettings::NumBakeSamples != numBakeSamples)
    {
        bakeSampleMode = AppSettings::BakeSampleMode;
        numBakeSamples = AppSettings::NumBakeSamples;

        const uint64 numGroupsX = (lightMapSize + (BakeGroupSizeX - 1)) / BakeGroupSizeX;
        const uint64 numGroupsY = (lightMapSize + (BakeGroupSizeY - 1)) / BakeGroupSizeY;
        if(s_BakeSetting.SupportsProgressiveIntegration(bakeMode, solveMode))
            currNumBakeBatches = numGroupsX * numGroupsY * AppSettings::NumBakeSamples * AppSettings::NumBakeSamples;
        else
            currNumBakeBatches = numGroupsX * numGroupsY * BakeGroupSize;

        InterlockedIncrement64(&bakeTag);
        currBakeBatch = 0;
    }

    MeshBakerStatus status;
    const uint64 sgCount = s_BakeSetting.SGCount();
    for(uint64 i = 0; i < sgCount; ++i)
        status.SGDirections[i] = sgDirections[i];
    status.SGSharpness = sgCount > 0 ? sgSharpness : 0.0f;

    status.BakeProgress = Saturate(currBakeBatch / (currNumBakeBatches - 1.0f));
    return status;
}

void MeshBaker::WaitBakeThreadEnd() 
{
    KillBakeThreads();
}

void MeshBaker::KillBakeThreads()
{
    Assert_(!killBakeThreads);
    killBakeThreads = true;
    for(uint64 i = 0; i < bakeThreads.size(); ++i)
    {
        WaitForSingleObject(bakeThreads[i], INFINITE);
        CloseHandle(bakeThreads[i]);
    }

    bakeThreads.clear();
    bakeThreadData.clear();
}

void MeshBaker::StartBakeThreads()
{
    Assert_(killBakeThreads);
    if(bakeThreads.size() > 0)
        return;

    uint32 (__stdcall* threadFunction)(void*) = BakeThread<DiffuseBaker>;
    auto bm = s_BakeSetting.BakeMode;
    if( bm == BakeModes::HL2)
        threadFunction = BakeThread<HL2Baker>;
	else if (bm == BakeModes::Directional)
		threadFunction = BakeThread<DirectionalBaker>;
    else if(bm == BakeModes::DirectionalRGB)
        threadFunction = BakeThread<DirectionalRGBBaker>;
    else if(bm == BakeModes::SH4)
        threadFunction = BakeThread<SH4Baker>;
    else if(bm == BakeModes::SH9)
        threadFunction = BakeThread<SH9Baker>;
    else if(bm == BakeModes::H4)
        threadFunction = BakeThread<H4Baker>;
    else if(bm == BakeModes::H6)
        threadFunction = BakeThread<H6Baker>;
    else if(bm == BakeModes::SG5)
        threadFunction = BakeThread<SG5Baker>;
    else if(bm == BakeModes::SG6)
        threadFunction = BakeThread<SG6Baker>;
    else if(bm == BakeModes::SG9)
        threadFunction = BakeThread<SG9Baker>;
    else if(bm == BakeModes::SG12)
        threadFunction = BakeThread<SG12Baker>;

    bakeThreads.resize(numThreads);
    bakeThreadData.resize(numThreads);
    for(uint64 i = 0; i < numThreads; ++i)
    {
        BakeThreadData* threadData = &bakeThreadData[i];
        threadData->BakeOutput = bakeResults;
        threadData->Samples = &bakeSamples;
        threadData->CurrBatch = &currBakeBatch;
        threadData->Baker = this;
        bakeThreads[i] = HANDLE(_beginthreadex(nullptr, 0, threadFunction, threadData, 0, nullptr));
        if(bakeThreads[i] == 0)
        {
            AssertFail_("Failed to create thread for light map baking");
            throw Exception(L"Failed to create thread for light map baking");
        }
    }

    bakeThreadsSuspended = false;
}

void MeshBaker::KillRenderThreads()
{
    if(renderThreadsSuspended)
        return;

    Assert_(killRenderThreads == false);
    killRenderThreads = true;
    for(uint64 i = 0; i < renderThreads.size(); ++i)
    {
        WaitForSingleObject(renderThreads[i], INFINITE);
        CloseHandle(renderThreads[i]);
    }

    renderThreads.clear();
    renderThreadData.clear();
    killRenderThreads = false;
    renderThreadsSuspended = true;
}

void MeshBaker::StartRenderThreads()
{
    if(renderThreadsSuspended == false)
        return;

    Assert_(killRenderThreads == false);
    if(renderThreads.size() > 0)
        return;

    renderThreads.resize(numThreads);
    renderThreadData.resize(numThreads);
    for(uint64 i = 0; i < numThreads; ++i)
    {
        RenderThreadData* threadData = &renderThreadData[i];
        threadData->RenderBuffer = &renderBuffer;
        threadData->RenderWeightBuffer = &renderWeightBuffer;
        threadData->Samples = &renderSamples;
        threadData->CurrTile = &currTile;
        threadData->Baker = this;
        renderThreads[i] = HANDLE(_beginthreadex(nullptr, 0, RenderThread, threadData, 0, nullptr));
        if(renderThreads[i] == 0)
        {
            AssertFail_("Failed to create thread for ground truth rendering");
            throw Exception(L"Failed to create thread for ground truth rendering");
        }
    }

    renderThreadsSuspended = false;
}