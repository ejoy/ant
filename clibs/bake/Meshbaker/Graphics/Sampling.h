//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "glm/glm.hpp"
#include "glm/gtx/compatibility.hpp"

#include "Constants.h"
#include "Math.h"

namespace Graphics
{

// Maps a value inside the square [0,1]x[0,1] to a value in a disk of radius 1 using concentric squares.
// This mapping preserves area, bi continuity, and minimizes deformation.
// Based off the algorithm "A Low Distortion Map Between Disk and Square" by Peter Shirley and
// Kenneth Chiu. Also includes polygon morphing modification from "CryEngine3 Graphics Gems"
// by Tiago Sousa
inline glm::vec2 SquareToConcentricDiskMapping(float x, float y, float numSides, float polygonAmount)
{
    float phi, r;

    // -- (a,b) is now on [-1,1]?
    float a = 2.0f * x - 1.0f;
    float b = 2.0f * y - 1.0f;

    if(a > -b)                      // region 1 or 2
    {
        if(a > b)                   // region 1, also |a| > |b|
        {
            r = a;
            phi = (Pi / 4.0f) * (b / a);
        }
        else                        // region 2, also |b| > |a|
        {
            r = b;
            phi = (Pi / 4.0f) * (2.0f - (a / b));
        }
    }
    else                            // region 3 or 4
    {
        if(a < b)                   // region 3, also |a| >= |b|, a != 0
        {
            r = -a;
            phi = (Pi / 4.0f) * (4.0f + (b / a));
        }
        else                        // region 4, |b| >= |a|, but a==0 and b==0 could occur.
        {
            r = -b;
            if(b != 0)
                phi = (Pi / 4.0f) * (6.0f - (a / b));
            else
                phi = 0;
        }
    }

    const float N = numSides;
    float polyModifier = std::cos(Pi / N) / std::cos(phi - (Pi2 / N) * std::floor((N * phi + Pi) / Pi2));
    r *= glm::lerp(1.0f, polyModifier, polygonAmount);

    glm::vec2 result;
    result.x = r * std::cos(phi);
    result.y = r * std::sin(phi);

    return result;
}

// Maps a value inside the square [0,1]x[0,1] to a value in a disk of radius 1 using concentric squares.
// This mapping preserves area, bi continuity, and minimizes deformation.
// Based off the algorithm "A Low Distortion Map Between Disk and Square" by Peter Shirley and
// Kenneth Chiu.
inline glm::vec2 SquareToConcentricDiskMapping(float x, float y)
{
    float phi = 0.0f;
    float r = 0.0f;

    // -- (a,b) is now on [-1,1]?
    float a = 2.0f * x - 1.0f;
    float b = 2.0f * y - 1.0f;

    if(a > -b)                      // region 1 or 2
    {
        if(a > b)                   // region 1, also |a| > |b|
        {
            r = a;
            phi = (Pi / 4.0f) * (b / a);
        }
        else                        // region 2, also |b| > |a|
        {
            r = b;
            phi = (Pi / 4.0f) * (2.0f - (a / b));
        }
    }
    else                            // region 3 or 4
    {
        if(a < b)                   // region 3, also |a| >= |b|, a != 0
        {
            r = -a;
            phi = (Pi / 4.0f) * (4.0f + (b / a));
        }
        else                        // region 4, |b| >= |a|, but a==0 and b==0 could occur.
        {
            r = -b;
            if(b != 0)
                phi = (Pi / 4.0f) * (6.0f - (a / b));
            else
                phi = 0;
        }
    }

    glm::vec2 result;
    result.x = r * std::cos(phi);
    result.y = r * std::sin(phi);
    return result;
}

// Returns a microfacet normal (half direction) that can be be used to compute a
// reflected lighting direction. The PDF is equal to D(m) * dot(n, m)
inline glm::vec3 SampleGGXMicrofacet(float roughness, float u1, float u2)
{
    float theta = std::atan2(roughness * std::sqrt(u1), std::sqrt(1 - u1));
    float phi = 2 * Pi * u2;

    glm::vec3 h;
    h.x = std::sin(theta) * std::cos(phi);
    h.y = std::sin(theta) * std::sin(phi);
    h.z = std::cos(theta);

    return h;
}

// Returns a world-space lighting direction for sampling a GGX distribution.
inline glm::vec3 SampleDirectionGGX(const glm::vec3& v, const glm::vec3& n, float roughness,
                                 const glm::mat3& tangentToWorld, float u1, float u2)
{
    glm::vec3 h = SampleGGXMicrofacet(roughness, u1, u2);

    // Convert to world space
    h = glm::normalize(tangentToWorld * h);

    // Reflect the view vector about the microfacet normal
    float hDotV = glm::dot(h, v);
    glm::vec3 sampleDir = 2.0f * hDotV * h - v;
    return glm::normalize(sampleDir);
}

// Returns the PDF for a particular GGX sample after reflecting the view vector
// about a microfacet normal (includes the Jacobian for going from half vector to lighting vector)
inline float GGX_PDF(const glm::vec3& n, const glm::vec3& h, const glm::vec3& v, float roughness)
{
    float nDotH = glm::clamp(glm::dot(n, h), 0.f, 1.f);
    float hDotV = glm::clamp(glm::dot(h, v), 0.f, 1.f);
    float m2 = roughness * roughness;
    float vv = nDotH * nDotH * (m2 - 1.f) + 1.f;
    float d = m2 / (Pi * vv * vv);
    float pM = d * nDotH;
    return pM / (4 * hDotV);
}

// Returns a point inside of a unit sphere
inline glm::vec3 SampleSphere(float x1, float x2, float x3, float u1)
{
    glm::vec3 xyz = glm::vec3(x1, x2, x3) * 2.0f - 1.0f;
    float scale = std::pow(u1, 1.0f / 3.0f) / glm::length(xyz);
    return xyz * scale;
}

// Returns a random direction on the unit sphere
inline glm::vec3 SampleDirectionSphere(float u1, float u2)
{
    float z = u1 * 2.0f - 1.0f;
    float r = std::sqrt(std::max(0.0f, 1.0f - z * z));
    float phi = 2 * Pi * u2;
    float x = r * std::cos(phi);
    float y = r * std::sin(phi);

    return glm::vec3(x, y, z);
}

// Returns a random direction on the hemisphere around z = 1
inline glm::vec3 SampleDirectionHemisphere(float u1, float u2)
{
    float z = u1;
    float r = std::sqrt(std::max(0.0f, 1.0f - z * z));
    float phi = 2 * Pi * u2;
    float x = r * std::cos(phi);
    float y = r * std::sin(phi);

    return glm::vec3(x, y, z);
}

// Returns a random cosine-weighted direction on the hemisphere around z = 1
inline glm::vec3 SampleCosineHemisphere(float u1, float u2)
{
    glm::vec2 uv = SquareToConcentricDiskMapping(u1, u2);
    float u = uv.x;
    float v = uv.y;

    // Project samples on the disk to the hemisphere to get a
    // cosine weighted distribution
    glm::vec3 dir;
    float r = u * u + v * v;
    dir.x = u;
    dir.y = v;
    dir.z = std::sqrt(std::max(0.0f, 1.0f - r));

    return dir;
}

inline glm::vec3 SampleStratifiedCosineHemisphere(uint64_t sX, uint64_t sY, uint64_t sqrtNumSamples, float u1, float u2)
{
   // Jitter the samples
    float jitteredX = (sX + u1) / sqrtNumSamples;
    float jitteredY = (sY + u2) / sqrtNumSamples;

    // Map jittered samples to disk using a concentric mapping
    glm::vec2 uv = SquareToConcentricDiskMapping(jitteredX, jitteredY);
    float u = uv.x;
    float v = uv.y;

    // Project samples on the disk to the hemisphere to get a
    // cosine weighted distribution
    glm::vec3 dir;
    float r = u * u + v * v;
    dir.x = u;
    dir.y = v;
    dir.z = std::sqrt(std::max(0.0f, 1.0f - r));

    return dir;
}

inline glm::vec3 SampleStratifiedCosineHemisphere(uint64_t sampleIdx, uint64_t sqrtNumSamples, float u1, float u2)
{
    uint64_t x = sampleIdx % sqrtNumSamples;
    uint64_t y = sampleIdx / sqrtNumSamples;

    return SampleStratifiedCosineHemisphere(x, y, sqrtNumSamples, u1, u2);
}

// Generate random spherical sample
inline glm::vec3 GenerateRandomSphericalSample(float u1, float u2)
{
    // Generate unbiased distribution of spherical coordinates
    float x = u1;
    float y = u2;
    float theta = 2.0f * std::acosf(std::sqrtf(1.0f - x));
    float phi = 2.0f * Pi * y;

    //  Convert spherical coordinates to unit vector
    glm::vec3 vec;
    SphericalToCartesianXYZYUP(1.0f, theta, phi, vec);

    return vec;
}

static const float OneMinusEpsilon = 0.9999999403953552f;

// Computes a radical inverse with base 2 using crazy bit-twiddling from "Hacker's Delight"
inline float RadicalInverseBase2(uint32_t bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10f; // / 0x100000000
}

float RadicalInverseFast(uint64_t baseIndex, uint64_t index);

// Returns a single 2D point in a Hammersley sequence of length "numSamples", using base 1 and base 2
inline glm::vec2 Hammersley2D(uint64_t sampleIdx, uint64_t numSamples)
{
    return glm::vec2(float(sampleIdx) / float(numSamples), RadicalInverseBase2(uint32_t(sampleIdx)));
}

inline void GenerateRandomSamples2D(glm::vec2* samples, uint64_t numSamples, Random& randomGenerator)
{
    for(uint64_t i = 0; i < numSamples; ++i)
        samples[i] = randomGenerator.RandomFloat2();
}

inline void GenerateStratifiedSamples2D(glm::vec2* samples, uint64_t numSamplesX, uint64_t numSamplesY, Random& randomGenerator)
{
    const glm::vec2 delta = glm::vec2(1.0f / numSamplesX, 1.0f / numSamplesY);
    uint64_t sampleIdx = 0;
    for(uint64_t y = 0; y < numSamplesY; ++y)
    {
        for(uint64_t x = 0; x < numSamplesX; ++x)
        {
            glm::vec2& currSample = samples[sampleIdx];
            currSample = glm::vec2(float(x), float(y)) + randomGenerator.RandomFloat2();
            currSample *= delta;
            currSample = glm::clamp(currSample, 0.0f, OneMinusEpsilon);

            ++sampleIdx;
        }
    }
}

inline void GenerateGridSamples2D(glm::vec2* samples, uint64_t numSamplesX, uint64_t numSamplesY)
{
    const glm::vec2 delta = glm::vec2(1.0f / numSamplesX, 1.0f / numSamplesY);
    uint64_t sampleIdx = 0;
    for(uint64_t y = 0; y < numSamplesY; ++y)
    {
        for(uint64_t x = 0; x < numSamplesX; ++x)
        {
            glm::vec2& currSample = samples[sampleIdx];
            currSample = glm::vec2(float(x), float(y));
            currSample *= delta;

            ++sampleIdx;
        }
    }
}

// Generates hammersley using base 1 and 2
inline void GenerateHammersleySamples2D(glm::vec2* samples, uint64_t numSamples)
{
    for(uint64_t i = 0; i < numSamples; ++i)
        samples[i] = Hammersley2D(i, numSamples);
}

// Generates hammersley using arbitrary bases
inline void GenerateHammersleySamples2D(glm::vec2* samples, uint64_t numSamples, uint64_t dimIdx)
{
    if(dimIdx == 0)
    {
        GenerateHammersleySamples2D(samples, numSamples);
    }
    else
    {
        uint64_t baseIdx0 = dimIdx * 2 - 1;
        uint64_t baseIdx1 = baseIdx0 + 1;
        for(uint64_t i = 0; i < numSamples; ++i)
            samples[i] = glm::vec2(RadicalInverseFast(baseIdx0, i), RadicalInverseFast(baseIdx1, i));
    }
}


inline void GenerateLatinHypercubeSamples2D(glm::vec2* samples, uint64_t numSamples, Random& rng)
{
    // Generate LHS samples along diagonal
    const glm::vec2 delta = glm::vec2(1.0f / numSamples, 1.0f / numSamples);
    for(uint64_t i = 0; i < numSamples; ++i)
    {
        glm::vec2 currSample = glm::vec2(float(i)) + rng.RandomFloat2();
        currSample *= delta;
        samples[i] =  glm::clamp(currSample, 0.0f, OneMinusEpsilon);
    }

    // Permute LHS samples in each dimension
    float* samples1D = reinterpret_cast<float*>(samples);
    const uint64_t numDims = 2;
    for(uint64_t i = 0; i < numDims; ++i)
    {
        for(uint64_t j = 0; j < numSamples; ++j)
        {
            uint64_t other = j + (rng.RandomUint() % (numSamples - j));
            std::swap(samples1D[numDims * j + i], samples1D[numDims * other + i]);
        }
    }
}

glm::vec2 SampleCMJ2D(int32_t sampleIdx, int32_t numSamplesX, int32_t numSamplesY, int32_t pattern);
void GenerateCMJSamples2D(glm::vec2* samples, uint64_t numSamplesX, uint64_t numSamplesY, uint32_t pattern);

}