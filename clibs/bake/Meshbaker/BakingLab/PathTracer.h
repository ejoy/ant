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
#include <Graphics/Textures.h>
#include <Graphics/Skybox.h>

#include "AppSettings.h"

// Forward declarations
struct __RTCScene;
typedef __RTCScene* RTCScene;

using namespace SampleFramework11;

// Single vertex in the mesh vertex buffer
struct Vertex
{
    Float3 Position;
    Float3 Normal;
    Float2 TexCoord;
    Float2 LightMapUV;
    Float3 Tangent;
    Float3 Bitangent;
};

// Data returned after building a BVH
struct BVHData
{
    RTCDevice Device = nullptr;
    RTCScene Scene = nullptr;
    std::vector<Uint3> Triangles;
    std::vector<Vertex> Vertices;
    std::vector<uint16> MaterialIndices;
    std::vector<TextureData<UByte4N>> MaterialDiffuseMaps;
    std::vector<TextureData<UByte4N>> MaterialNormalMaps;
    std::vector<TextureData<UByte4N>> MaterialRoughnessMaps;
    std::vector<TextureData<UByte4N>> MaterialMetallicMaps;

    ~BVHData()
    {
        if(Scene != nullptr)
        {
            rtcDeleteScene(Scene);
            Scene = nullptr;
        }
    }
};

// Wrapper for an embree ray
struct EmbreeRay : public RTCRay
{
    EmbreeRay(const Float3& origin, const Float3& direction, float nearDist = 0.0f, float farDist = FLT_MAX)
    {
        org[0] = origin.x;
        org[1] = origin.y;
        org[2] = origin.z;
        dir[0] = direction.x;
        dir[1] = direction.y;
        dir[2] = direction.z;
        tnear = nearDist;
        tfar = farDist;
        geomID = RTC_INVALID_GEOMETRY_ID;
        primID = RTC_INVALID_GEOMETRY_ID;
        instID = RTC_INVALID_GEOMETRY_ID;
        mask = 0xFFFFFFFF;
        time = 0.0f;
    }

    bool Hit() const
    {
        return geomID != RTC_INVALID_GEOMETRY_ID;
    }

    Float3 Origin() const
    {
        return Float3(org[0], org[1], org[2]);
    }

    Float3 Direction() const
    {
        return Float3(dir[0], dir[1], dir[2]);
    }
};

StaticAssert_(sizeof(EmbreeRay) == sizeof(RTCRay));

enum class IntegrationTypes
{
    Pixel = 0,
    Lens,
    BRDF,
    Sun,
    AreaLight,

    NumValues,
};

static const uint64 NumIntegrationTypes = uint64(IntegrationTypes::NumValues);

// A list of pseudo-random sample points used for Monte Carlo integration, with enough
// sample points for a group of adjacent pixels/texels
struct IntegrationSamples
{
    std::vector<Float2> Samples;
    uint64 NumPixels = 0;
    uint64 NumTypes = 0;
    uint64 NumSamples = 0;

    void Init(uint64 numPixels, uint64 numTypes, uint64 numSamples)
    {
        NumPixels = numPixels;
        NumSamples = numSamples;
        NumTypes = numTypes;
        Samples.resize(numPixels * numTypes * numSamples);
    }

    uint64 ArrayIndex(uint64 pixelIdx, uint64 typeIdx, uint64 sampleIdx) const
    {
        Assert_(pixelIdx < NumPixels);
        Assert_(typeIdx < NumTypes);
        Assert_(sampleIdx < NumSamples);
        return pixelIdx * (NumSamples * NumTypes) + typeIdx * NumSamples + sampleIdx;
    }

    Float2 GetSample(uint64 pixelIdx, uint64 typeIdx, uint64 sampleIdx) const
    {
        const uint64 idx = ArrayIndex(pixelIdx, typeIdx, sampleIdx);
        return Samples[idx];
    }

    Float2* GetSamplesForType(uint64 pixelIdx, uint64 typeIdx)
    {
        const uint64 startIdx = ArrayIndex(pixelIdx, typeIdx, 0);
        return &Samples[startIdx];
    }

    const Float2* GetSamplesForType(uint64 pixelIdx, uint64 typeIdx) const
    {
        const uint64 startIdx = ArrayIndex(pixelIdx, typeIdx, 0);
        return &Samples[startIdx];
    }

    void GetSampleSet(uint64 pixelIdx, uint64 sampleIdx, Float2* sampleSet) const
    {
        Assert_(pixelIdx < NumPixels);
        Assert_(sampleIdx < NumSamples);
        Assert_(sampleSet != nullptr);
        const uint64 typeStride = NumSamples;
        uint64 idx = pixelIdx * (NumSamples * NumTypes) + sampleIdx;
        for(uint64 typeIdx = 0; typeIdx < NumTypes; ++typeIdx)
        {
            sampleSet[typeIdx] = Samples[idx];
            idx += typeStride;
        }
    }
};

// A single set of sample points for running a single step of the path tracer
struct IntegrationSampleSet
{
    Float2 Samples[NumIntegrationTypes];

    void Init(const IntegrationSamples& samples, uint64 pixelIdx, uint64 sampleIdx)
    {
        Assert_(samples.NumTypes == NumIntegrationTypes);
        samples.GetSampleSet(pixelIdx, sampleIdx, Samples);
    }

    Float2 Pixel() const { return Samples[uint64(IntegrationTypes::Pixel)]; }
    Float2 Lens() const { return Samples[uint64(IntegrationTypes::Lens)]; }
    Float2 BRDF() const { return Samples[uint64(IntegrationTypes::BRDF)]; }
    Float2 Sun() const { return Samples[uint64(IntegrationTypes::Sun)]; }
    Float2 AreaLight() const { return Samples[uint64(IntegrationTypes::AreaLight)]; }
};

// Generates a full list of sample points for all integration types
void GenerateIntegrationSamples(IntegrationSamples& samples, uint64 sqrtNumSamples, uint64 tileSizeX, uint64 tileSizeY,
                                SampleModes sampleMode, uint64 numIntegrationTypes, Random& rng);

// Samples the spherical area light using a set of 2D sample points
Float3 SampleAreaLight(const Float3& position, const Float3& normal, RTCScene scene,
                       const Float3& diffuseAlbedo, const Float3& cameraPos,
                       bool includeSpecular, Float3 specAlbedo, float roughness,
                       float u1, float u2, Float3& irradiance, Float3& sampleDir);

Float3 SampleSunLight(const Float3& position, const Float3& normal, RTCScene scene,
                      const Float3& diffuseAlbedo, const Float3& cameraPos,
                      bool includeSpecular, Float3 specAlbedo, float roughness,
                      float u1, float u2, Float3& irradiance);

// Options for path tracing
struct PathTracerParams
{
    Float3 RayDir;
    uint32 EnableDirectAreaLight = false;
    uint8 EnableDirectSun = false;
    uint8 EnableDiffuse = false;
    uint8 EnableSpecular = false;
    uint8 EnableBounceSpecular = false;
    uint8 ViewIndirectSpecular = false;
    uint8 ViewIndirectDiffuse = false;
    int32 MaxPathLength = -1;
    int32 RussianRouletteDepth = -1;
    float RussianRouletteProbability = 0.5f;
    Float3 RayStart;
    float RayLen = 0.0f;
    const BVHData* SceneBVH = nullptr;
    const IntegrationSampleSet* SampleSet = nullptr;
    const SkyCache* SkyCache = nullptr;
    const TextureData<Half4>* EnvMaps = nullptr;
};

// Returns the incoming radiance along the ray specified by "RayDir", computed using unidirectional
// path tracing
Float3 PathTrace(const PathTracerParams& params, Random& randomGenerator, float& illuminance, bool& hitSky);