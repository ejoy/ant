//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once
#include "glm/glm.hpp"
#include "glm/gtx/compatibility.hpp"

#include <vector>

namespace Graphics
{
template<typename T> struct TextureData
{
    std::vector<T> Texels;
    uint32_t Width = 0;
    uint32_t Height = 0;
    uint32_t NumSlices = 0;

    void Init(uint32_t width, uint32_t height, uint32_t numSlices)
    {
        Width = width;
        Height = height;
        NumSlices = numSlices;
        Texels.resize(width * height * numSlices);
    }
};

// == Texture Sampling Functions ==================================================================

template<typename T> static glm::vec4 SampleTexture2D(glm::vec2 uv, uint32_t arraySlice, const std::vector<T>& texels,
                                                     uint32_t texWidth, uint32_t texHeight, uint32_t numSlices)
{
    glm::vec2 texSize = glm::vec2(float(texWidth), float(texHeight));
    glm::vec2 halfTexelSize(0.5f / texSize.x, 0.5f / texSize.y);
    glm::vec2 samplePos = glm::fract(uv - halfTexelSize);
    if(samplePos.x < 0.0f)
        samplePos.x = 1.0f + samplePos.x;
    if(samplePos.y < 0.0f)
        samplePos.y = 1.0f + samplePos.y;
    samplePos *= texSize;
    uint32_t samplePosX = std::min(uint32_t(samplePos.x), texWidth - 1);
    uint32_t samplePosY = std::min(uint32_t(samplePos.y), texHeight - 1);
    uint32_t samplePosXNext = std::min(samplePosX + 1, texWidth - 1);
    uint32_t samplePosYNext = std::min(samplePosY + 1, texHeight - 1);

    glm::vec2 lerpAmts = glm::fract(samplePos);

    numSlices = std::max<uint32_t>(numSlices, 1);
    const uint32_t sliceOffset = std::min(arraySlice, numSlices) * texWidth * texHeight;

    glm::vec4 samples[4];
    samples[0] = texels[sliceOffset + samplePosY * texWidth + samplePosX];
    samples[1] = texels[sliceOffset + samplePosY * texWidth + samplePosXNext];
    samples[2] = texels[sliceOffset + samplePosYNext * texWidth + samplePosX];
    samples[3] = texels[sliceOffset + samplePosYNext * texWidth + samplePosXNext];

    // lerp between the shadow values to calculate our light amount
    return glm::lerp(glm::lerp(samples[0], samples[1], lerpAmts.x),
                    glm::lerp(samples[2], samples[3], lerpAmts.x), lerpAmts.y);
}

template<typename T> static glm::vec4 SampleTexture2D(glm::vec2 uv, uint32_t arraySlice, const TextureData<T>& texData)
{
    return SampleTexture2D(uv, arraySlice, texData.Texels, texData.Width, texData.Height, texData.NumSlices);
}

template<typename T> static glm::vec4 SampleTexture2D(glm::vec2 uv, const TextureData<T>& texData)
{
    return SampleTexture2D(uv, 0, texData.Texels, texData.Width, texData.Height, texData.NumSlices);
}

template<typename T> static glm::vec4 SampleCubemap(glm::vec3 direction, const TextureData<T>& texData)
{
    assert(texData.NumSlices == 6);

    float maxComponent = std::max(std::max(std::abs(direction.x), std::abs(direction.y)), std::abs(direction.z));
    uint32_t faceIdx = 0;
    glm::vec2 uv = glm::vec2(direction.y, direction.z);
    if(direction.x == maxComponent)
    {
        faceIdx = 0;
        uv = glm::vec2(-direction.z, -direction.y) / direction.x;
    }
    else if(-direction.x == maxComponent)
    {
        faceIdx = 1;
        uv = glm::vec2(direction.z, -direction.y) / -direction.x;
    }
    else if(direction.y == maxComponent)
    {
        faceIdx = 2;
        uv = glm::vec2(direction.x, direction.z) / direction.y;
    }
    else if(-direction.y == maxComponent)
    {
        faceIdx = 3;
        uv = glm::vec2(direction.x, -direction.z) / -direction.y;
    }
    else if(direction.z == maxComponent)
    {
        faceIdx = 4;
        uv = glm::vec2(direction.x, -direction.y) / direction.z;
    }
    else if(-direction.z == maxComponent)
    {
        faceIdx = 5;
        uv = glm::vec2(-direction.x, -direction.y) / -direction.z;
    }

    uv = uv * glm::vec2(0.5f, 0.5f) + glm::vec2(0.5f, 0.5f);
    return SampleTexture2D(uv, faceIdx, texData);
}

}