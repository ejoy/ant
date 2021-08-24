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

#include "glm/glm.hpp"
#include "Graphics/Math.h"
#include "Graphics/Textures.h"
#include "Setting.h"

#include "3rd/Embree-2.8/include/embree2/rtcore.h"
#include "3rd/Embree-2.8/include/embree2/rtcore_ray.h"
#include <vector>

// Single vertex in the mesh vertex buffer
struct Vertex
{
    glm::vec3 Position;
    glm::vec3 Normal;
    glm::vec2 TexCoord;
    glm::vec2 LightMapUV;
    glm::vec3 Tangent;
    glm::vec3 Bitangent;
};

// Data returned after building a BVH
struct BVHData
{
    RTCDevice Device = nullptr;
    RTCScene Scene = nullptr;
    std::vector<glm::u32vec4> Triangles;
    std::vector<Vertex> Vertices;
    std::vector<uint16_t> MaterialIndices;
    std::vector<Graphics::TextureData<glm::u8vec4>> MaterialDiffuseMaps;
    std::vector<Graphics::TextureData<glm::u8vec4>> MaterialNormalMaps;
    std::vector<Graphics::TextureData<glm::u8vec4>> MaterialRoughnessMaps;
    std::vector<Graphics::TextureData<glm::u8vec4>> MaterialMetallicMaps;

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
    EmbreeRay(const glm::vec3& origin, const glm::vec3& direction, float nearDist = 0.0f, float farDist = FLT_MAX)
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

    glm::vec3 Origin() const
    {
        return glm::vec3(org[0], org[1], org[2]);
    }

    glm::vec3 Direction() const
    {
        return glm::vec3(dir[0], dir[1], dir[2]);
    }
};

static_assert(sizeof(EmbreeRay) == sizeof(RTCRay), "EmbreeRay not match RTCRay");

enum class IntegrationTypes
{
    Pixel = 0,
    Lens,
    BRDF,
    Sun,
    AreaLight,

    NumValues,
};

static const uint64_t NumIntegrationTypes = uint64_t(IntegrationTypes::NumValues);

// A list of pseudo-random sample points used for Monte Carlo integration, with enough
// sample points for a group of adjacent pixels/texels
struct IntegrationSamples
{
    std::vector<glm::vec2> Samples;
    uint64_t NumPixels = 0;
    uint64_t NumTypes = 0;
    uint64_t NumSamples = 0;

    void Init(uint64_t numPixels, uint64_t numTypes, uint64_t numSamples)
    {
        NumPixels = numPixels;
        NumSamples = numSamples;
        NumTypes = numTypes;
        Samples.resize(numPixels * numTypes * numSamples);
    }

    uint64_t ArrayIndex(uint64_t pixelIdx, uint64_t typeIdx, uint64_t sampleIdx) const
    {
        assert(pixelIdx < NumPixels);
        assert(typeIdx < NumTypes);
        assert(sampleIdx < NumSamples);
        return pixelIdx * (NumSamples * NumTypes) + typeIdx * NumSamples + sampleIdx;
    }

    glm::vec2 GetSample(uint64_t pixelIdx, uint64_t typeIdx, uint64_t sampleIdx) const
    {
        const uint64_t idx = ArrayIndex(pixelIdx, typeIdx, sampleIdx);
        return Samples[idx];
    }

    glm::vec2* GetSamplesForType(uint64_t pixelIdx, uint64_t typeIdx)
    {
        const uint64_t startIdx = ArrayIndex(pixelIdx, typeIdx, 0);
        return &Samples[startIdx];
    }

    const glm::vec2* GetSamplesForType(uint64_t pixelIdx, uint64_t typeIdx) const
    {
        const uint64_t startIdx = ArrayIndex(pixelIdx, typeIdx, 0);
        return &Samples[startIdx];
    }

    void GetSampleSet(uint64_t pixelIdx, uint64_t sampleIdx, glm::vec2* sampleSet) const
    {
        assert(pixelIdx < NumPixels);
        assert(sampleIdx < NumSamples);
        assert(sampleSet != nullptr);
        const uint64_t typeStride = NumSamples;
        uint64_t idx = pixelIdx * (NumSamples * NumTypes) + sampleIdx;
        for(uint64_t typeIdx = 0; typeIdx < NumTypes; ++typeIdx)
        {
            sampleSet[typeIdx] = Samples[idx];
            idx += typeStride;
        }
    }
};

// A single set of sample points for running a single step of the path tracer
struct IntegrationSampleSet
{
    glm::vec2 Samples[NumIntegrationTypes];

    void Init(const IntegrationSamples& samples, uint64_t pixelIdx, uint64_t sampleIdx)
    {
        assert(samples.NumTypes == NumIntegrationTypes);
        samples.GetSampleSet(pixelIdx, sampleIdx, Samples);
    }

    glm::vec2 Pixel() const { return Samples[uint64_t(IntegrationTypes::Pixel)]; }
    glm::vec2 Lens() const { return Samples[uint64_t(IntegrationTypes::Lens)]; }
    glm::vec2 BRDF() const { return Samples[uint64_t(IntegrationTypes::BRDF)]; }
    glm::vec2 Sun() const { return Samples[uint64_t(IntegrationTypes::Sun)]; }
    glm::vec2 AreaLight() const { return Samples[uint64_t(IntegrationTypes::AreaLight)]; }
};

// Generates a full list of sample points for all integration types
void GenerateIntegrationSamples(IntegrationSamples& samples, uint64_t sqrtNumSamples, uint64_t tileSizeX, uint64_t tileSizeY,
                                SampleModes sampleMode, uint64_t numIntegrationTypes, Graphics::Random& rng);

// Samples the spherical area light using a set of 2D sample points
glm::vec3 SampleAreaLight(const glm::vec3& position, const glm::vec3& normal, RTCScene scene,
                       const glm::vec3& diffuseAlbedo, const glm::vec3& cameraPos,
                       bool includeSpecular, glm::vec3 specAlbedo, float roughness,
                       float u1, float u2, glm::vec3& irradiance, glm::vec3& sampleDir);

glm::vec3 SampleSunLight(const glm::vec3& position, const glm::vec3& normal, RTCScene scene,
                      const glm::vec3& diffuseAlbedo, const glm::vec3& cameraPos,
                      bool includeSpecular, glm::vec3 specAlbedo, float roughness,
                      float u1, float u2, glm::vec3& irradiance);

// Options for path tracing
struct PathTracerParams
{
    glm::vec3 RayDir;
    uint32_t EnableDirectAreaLight = false;
    uint8_t EnableDirectSun = false;
    uint8_t EnableDiffuse = false;
    uint8_t EnableSpecular = false;
    uint8_t EnableBounceSpecular = false;
    uint8_t ViewIndirectSpecular = false;
    uint8_t ViewIndirectDiffuse = false;
    int32_t MaxPathLength = -1;
    int32_t RussianRouletteDepth = -1;
    float RussianRouletteProbability = 0.5f;
    glm::vec3 RayStart;
    float RayLen = 0.0f;
    const BVHData* SceneBVH = nullptr;
    const IntegrationSampleSet* SampleSet = nullptr;
    //const SkyCache* SkyCache = nullptr;
    //const TextureData<Half4>* EnvMaps = nullptr;
};

// Returns the incoming radiance along the ray specified by "RayDir", computed using unidirectional
// path tracing
glm::vec3 PathTrace(const PathTracerParams& params, Graphics::Random& randomGenerator, float& illuminance, bool& hitSky);