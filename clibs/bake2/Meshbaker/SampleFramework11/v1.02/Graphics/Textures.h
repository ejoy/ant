//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"

#include "..\\InterfacePointers.h"
#include "..\\Serialization.h"

namespace SampleFramework11
{

struct Float4;
struct Half4;
struct UByte4N;
class File;

// Texture loading
ID3D11ShaderResourceViewPtr LoadTexture(ID3D11Device* device, const wchar* filePath, bool forceSRGB = false);

template<typename T> struct TextureData
{
    std::vector<T> Texels;
    uint32 Width = 0;
    uint32 Height = 0;
    uint32 NumSlices = 0;

    void Init(uint32 width, uint32 height, uint32 numSlices)
    {
        Width = width;
        Height = height;
        NumSlices = numSlices;
        Texels.resize(width * height * numSlices);
    }

    template<typename TSerializer> void Serialize(TSerializer& serializer)
    {
        SerializeRawVector(serializer, Texels);
        SerializeItem(serializer, Width);
        SerializeItem(serializer, Height);
        SerializeItem(serializer, NumSlices);
    }
};

// Decode a texture and copies it to the CPU
void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                    TextureData<UByte4N>& textureData);

void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                    TextureData<Half4>& textureData);

void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                    TextureData<Float4>& textureData);

ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device,
                                                     const TextureData<UByte4N>& textureData);

ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device,
                                                     const TextureData<Half4>& textureData);

ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device,
                                                     const TextureData<Float4>& textureData);

void SaveTextureAsDDS(ID3D11ShaderResourceView* srv, const wchar* filePath);
void SaveTextureAsDDS(ID3D11Resource* texture, const wchar* filePath);
void SaveTextureAsEXR(ID3D11ShaderResourceView* srv, const wchar* filePath);
void SaveTextureAsEXR(const TextureData<Float4>& texture, const wchar* filePath);
void SaveTextureAsPNG(ID3D11ShaderResourceView* srv, const wchar* filePath);
void SaveTextureAsPNG(ID3D11Resource* texture, const wchar* filePath);

Float3 MapXYSToDirection(uint64 x, uint64 y, uint64 s, uint64 width, uint64 height);

// == Texture Sampling Functions ==================================================================

template<typename T> static XMVECTOR SampleTexture2D(Float2 uv, uint32 arraySlice, const std::vector<T>& texels,
                                                     uint32 texWidth, uint32 texHeight, uint32 numSlices)
{
    Float2 texSize = Float2(float(texWidth), float(texHeight));
    Float2 halfTexelSize(0.5f / texSize.x, 0.5f / texSize.y);
    Float2 samplePos = Frac(uv - halfTexelSize);
    if(samplePos.x < 0.0f)
        samplePos.x = 1.0f + samplePos.x;
    if(samplePos.y < 0.0f)
        samplePos.y = 1.0f + samplePos.y;
    samplePos *= texSize;
    uint32 samplePosX = std::min(uint32(samplePos.x), texWidth - 1);
    uint32 samplePosY = std::min(uint32(samplePos.y), texHeight - 1);
    uint32 samplePosXNext = std::min(samplePosX + 1, texWidth - 1);
    uint32 samplePosYNext = std::min(samplePosY + 1, texHeight - 1);

    Float2 lerpAmts = Float2(Frac(samplePos.x), Frac(samplePos.y));

    numSlices = std::max<uint32>(numSlices, 1);
    const uint32 sliceOffset = std::min(arraySlice, numSlices) * texWidth * texHeight;

    XMVECTOR samples[4];
    samples[0] = texels[sliceOffset + samplePosY * texWidth + samplePosX].ToSIMD();
    samples[1] = texels[sliceOffset + samplePosY * texWidth + samplePosXNext].ToSIMD();
    samples[2] = texels[sliceOffset + samplePosYNext * texWidth + samplePosX].ToSIMD();
    samples[3] = texels[sliceOffset + samplePosYNext * texWidth + samplePosXNext].ToSIMD();

    // lerp between the shadow values to calculate our light amount
    return XMVectorLerp(XMVectorLerp(samples[0], samples[1], lerpAmts.x),
                        XMVectorLerp(samples[2], samples[3], lerpAmts.x), lerpAmts.y);
}

template<typename T> static XMVECTOR SampleTexture2D(Float2 uv, uint32 arraySlice, const TextureData<T>& texData)
{
    return SampleTexture2D(uv, arraySlice, texData.Texels, texData.Width, texData.Height, texData.NumSlices);
}

template<typename T> static XMVECTOR SampleTexture2D(Float2 uv, const TextureData<T>& texData)
{
    return SampleTexture2D(uv, 0, texData.Texels, texData.Width, texData.Height, texData.NumSlices);
}

template<typename T> static XMVECTOR SampleCubemap(Float3 direction, const TextureData<T>& texData)
{
    Assert_(texData.NumSlices == 6);

    float maxComponent = std::max(std::max(std::abs(direction.x), std::abs(direction.y)), std::abs(direction.z));
    uint32 faceIdx = 0;
    Float2 uv = Float2(direction.y, direction.z);
    if(direction.x == maxComponent)
    {
        faceIdx = 0;
        uv = Float2(-direction.z, -direction.y) / direction.x;
    }
    else if(-direction.x == maxComponent)
    {
        faceIdx = 1;
        uv = Float2(direction.z, -direction.y) / -direction.x;
    }
    else if(direction.y == maxComponent)
    {
        faceIdx = 2;
        uv = Float2(direction.x, direction.z) / direction.y;
    }
    else if(-direction.y == maxComponent)
    {
        faceIdx = 3;
        uv = Float2(direction.x, -direction.z) / -direction.y;
    }
    else if(direction.z == maxComponent)
    {
        faceIdx = 4;
        uv = Float2(direction.x, -direction.y) / direction.z;
    }
    else if(-direction.z == maxComponent)
    {
        faceIdx = 5;
        uv = Float2(-direction.x, -direction.y) / -direction.z;
    }

    uv = uv * Float2(0.5f, 0.5f) + Float2(0.5f, 0.5f);
    return SampleTexture2D(uv, faceIdx, texData);
}

}