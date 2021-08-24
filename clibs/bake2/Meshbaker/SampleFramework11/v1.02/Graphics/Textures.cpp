//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "..\\Utility.h"
#include "..\\Exceptions.h"
#include "Textures.h"
#include "DDSTextureLoader.h"
#include "WICTextureLoader.h"
#include "..\\FileIO.h"
#include "ShaderCompilation.h"
#include "GraphicsTypes.h"
#include "TinyEXR.h"

namespace SampleFramework11
{

static const DXGI_FORMAT UnormFormats[] =
{
    DXGI_FORMAT_R8G8B8A8_UNORM,
    DXGI_FORMAT_R8G8_UNORM,
    DXGI_FORMAT_R8_UNORM,

    DXGI_FORMAT_R16G16B16A16_UNORM,
    DXGI_FORMAT_R16G16_UNORM,
    DXGI_FORMAT_R16_UNORM,

    DXGI_FORMAT_R10G10B10A2_UNORM,
};

static bool IsUnormFormat(DXGI_FORMAT format)
{
    for(uint64 i = 0; i < ArraySize_(UnormFormats); ++i)
        if(format == UnormFormats[i])
            return true;
    return false;
}

// Loads a texture, using either the DDS loader or the WIC loader
ID3D11ShaderResourceViewPtr LoadTexture(ID3D11Device* device, const wchar* filePath, bool forceSRGB)
{
    ID3D11DeviceContextPtr context;
    device->GetImmediateContext(&context);

    ID3D11ResourcePtr resource;
    ID3D11ShaderResourceViewPtr srv;

    const std::wstring extension = GetFileExtension(filePath);
    if(extension == L"DDS" || extension == L"dds")
    {
        DXCall(DirectX::CreateDDSTextureFromFileEx(device, filePath, 0, D3D11_USAGE_DEFAULT,
                                                   D3D11_BIND_SHADER_RESOURCE, 0, 0, forceSRGB,
                                                   &resource, &srv, nullptr));
        return srv;
    }
    else
    {
        DXCall(DirectX:: CreateWICTextureFromFileEx(device, context, filePath, 0, D3D11_USAGE_DEFAULT,
                                                    D3D11_BIND_SHADER_RESOURCE, 0, 0, forceSRGB, &resource, &srv));

        return srv;
    }
}

template<typename T>
static void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                           DXGI_FORMAT outFormat, TextureData<T>& texData)
{
    static ComputeShaderPtr decodeTextureCS[2][2];
    static const uint32 TGSize = 16;

    if(decodeTextureCS[0][0].Valid() == false)
    {
        CompileOptions opts;
        opts.Add("TGSize_", TGSize);
        opts.Add("UnormOutput_", 0);
        const std::wstring shaderPath = SampleFrameworkDir() + L"Shaders\\DecodeTextureCS.hlsl";

        decodeTextureCS[0][0] = CompileCSFromFile(device, shaderPath.c_str(), "DecodeTextureCS", "cs_5_0", opts);
        decodeTextureCS[0][1] = CompileCSFromFile(device, shaderPath.c_str(), "DecodeTextureArrayCS", "cs_5_0", opts);

        opts.Reset();
        opts.Add("TGSize_", TGSize);
        opts.Add("UnormOutput_", 1);
        decodeTextureCS[1][0] = CompileCSFromFile(device, shaderPath.c_str(), "DecodeTextureCS", "cs_5_0", opts);
        decodeTextureCS[1][1] = CompileCSFromFile(device, shaderPath.c_str(), "DecodeTextureArrayCS", "cs_5_0", opts);
    }

    ID3D11Texture2DPtr texture;
    textureSRV->GetResource(reinterpret_cast<ID3D11Resource**>(&texture));

    D3D11_TEXTURE2D_DESC texDesc;
    texture->GetDesc(&texDesc);

    D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
    textureSRV->GetDesc(&srvDesc);

    ID3D11ShaderResourceViewPtr sourceSRV = textureSRV;
    uint32 arraySize = texDesc.ArraySize;
    if(srvDesc.ViewDimension == D3D11_SRV_DIMENSION_TEXTURECUBE
       || srvDesc.ViewDimension == D3D11_SRV_DIMENSION_TEXTURECUBEARRAY)
    {
        srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2DARRAY;
        srvDesc.Texture2DArray.ArraySize = arraySize;
        srvDesc.Texture2DArray.FirstArraySlice = 0;
        srvDesc.Texture2DArray.MostDetailedMip = 0;
        srvDesc.Texture2DArray.MipLevels = -1;
        DXCall(device->CreateShaderResourceView(texture, &srvDesc, &sourceSRV));
    }

    D3D11_TEXTURE2D_DESC decodeTextureDesc;
    decodeTextureDesc.Width = texDesc.Width;
    decodeTextureDesc.Height = texDesc.Height;
    decodeTextureDesc.ArraySize = arraySize;
    decodeTextureDesc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
    decodeTextureDesc.Format = outFormat;
    decodeTextureDesc.MipLevels = 1;
    decodeTextureDesc.MiscFlags = 0;
    decodeTextureDesc.SampleDesc.Count = 1;
    decodeTextureDesc.SampleDesc.Quality = 0;
    decodeTextureDesc.Usage = D3D11_USAGE_DEFAULT;
    decodeTextureDesc.CPUAccessFlags = 0;

    ID3D11Texture2DPtr decodeTexture;
    DXCall(device->CreateTexture2D(&decodeTextureDesc, nullptr, &decodeTexture));

    ID3D11UnorderedAccessViewPtr decodeTextureUAV;
    DXCall(device->CreateUnorderedAccessView(decodeTexture, nullptr, &decodeTextureUAV));

    ID3D11DeviceContextPtr context;
    device->GetImmediateContext(&context);

    SetCSInputs(context, sourceSRV);
    SetCSOutputs(context, decodeTextureUAV);

    uint32 arrayOutput = arraySize > 1 ? 1 : 0;
    uint32 unormOutput = IsUnormFormat(outFormat) ? 1 : 0;
    SetCSShader(context, decodeTextureCS[unormOutput][arrayOutput]);

    context->Dispatch(DispatchSize(TGSize, texDesc.Width), DispatchSize(TGSize, texDesc.Height), arraySize);

    ClearCSInputs(context);
    ClearCSOutputs(context);

    StagingTexture2D stagingTexture;
    stagingTexture.Initialize(device, texDesc.Width, texDesc.Height, outFormat, 1, 1, 0, arraySize);
    context->CopyResource(stagingTexture.Texture, decodeTexture);

    texData.Init(texDesc.Width, texDesc.Height, arraySize);

    for(uint32 slice = 0; slice < arraySize; ++slice)
    {
        uint32 pitch = 0;
        const uint8* srcData = reinterpret_cast<const uint8*>(stagingTexture.Map(context, slice, pitch));
        Assert_(pitch >= texDesc.Width * sizeof(T));

        const uint32 sliceOffset = texDesc.Width * texDesc.Height * slice;

        for(uint32 y = 0; y < texDesc.Height; ++y)
        {
            const T* rowData = reinterpret_cast<const T*>(srcData);

            for(uint32 x = 0; x < texDesc.Width; ++x)
                texData.Texels[y * texDesc.Width + x + sliceOffset] = rowData[x];

            srcData += pitch;
        }
    }
}

// Decode a texture into 32-bit floats and copies it to the CPU
void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                    TextureData<Float4>& textureData)
{
    GetTextureData(device, textureSRV, DXGI_FORMAT_R32G32B32A32_FLOAT, textureData);
}

// Decode a texture into 16-bit floats and copies it to the CPU
void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                    TextureData<Half4>& textureData)
{
    GetTextureData(device, textureSRV, DXGI_FORMAT_R16G16B16A16_FLOAT, textureData);
}

// Decode a texture into 32-bit floats and copies it to the CPU
void GetTextureData(ID3D11Device* device, ID3D11ShaderResourceView* textureSRV,
                    TextureData<UByte4N>& textureData)
{
    GetTextureData(device, textureSRV, DXGI_FORMAT_R8G8B8A8_UNORM, textureData);
}

template<typename T>
static ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device, const TextureData<T>& textureData)
{
    DXGI_FORMAT format = DXGI_FORMAT_UNKNOWN;
    if(typeid(T) == typeid(UByte4N))
        format = DXGI_FORMAT_R8G8B8A8_UNORM;
    else if(typeid(T) == typeid(Half4))
        format = DXGI_FORMAT_R16G16B16A16_FLOAT;
    else if(typeid(T) == typeid(Float4))
        format = DXGI_FORMAT_R32G32B32A32_FLOAT;

    Assert_(format != DXGI_FORMAT_UNKNOWN);

    const uint64 elemSize = sizeof(T);
    Assert_(textureData.Texels.size() > 0);
    Assert_(textureData.Width * textureData.Height * textureData.NumSlices == textureData.Texels.size());

    std::vector<D3D11_SUBRESOURCE_DATA> subResources;
    subResources.resize(textureData.NumSlices);
    for(uint64 i = 0; i < textureData.NumSlices; ++i)
    {
        subResources[i].pSysMem = &textureData.Texels[textureData.Width * textureData.Height * i];
        subResources[i].SysMemPitch = elemSize * textureData.Width;
        subResources[i].SysMemSlicePitch = 0;
    }

    D3D11_TEXTURE2D_DESC texDesc;
    texDesc.Width = textureData.Width;
    texDesc.Height = textureData.Height;
    texDesc.MipLevels = 1;
    texDesc.ArraySize = textureData.NumSlices;
    texDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    texDesc.SampleDesc.Count = 1;
    texDesc.SampleDesc.Quality = 0;
    texDesc.Usage = D3D11_USAGE_IMMUTABLE;
    texDesc.CPUAccessFlags = 0;
    texDesc.MiscFlags = 0;
    texDesc.Format = format;
    ID3D11Texture2DPtr texture;
    DXCall(device->CreateTexture2D(&texDesc, subResources.data(), &texture));

    ID3D11ShaderResourceViewPtr srv;
    DXCall(device->CreateShaderResourceView(texture, nullptr, &srv));

    return srv;
}

ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device, const TextureData<UByte4N>& textureData)
{
    return CreateSRVFromTextureData<UByte4N>(device, textureData);
}

ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device, const TextureData<Half4>& textureData)
{
    return CreateSRVFromTextureData<Half4>(device, textureData);
}

ID3D11ShaderResourceViewPtr CreateSRVFromTextureData(ID3D11Device* device, const TextureData<Float4>& textureData)
{
    return CreateSRVFromTextureData<Float4>(device, textureData);
}

void SaveTextureAsDDS(ID3D11ShaderResourceView* srv, const wchar* filePath)
{
    ID3D11ResourcePtr texture;
    srv->GetResource(&texture);

    SaveTextureAsDDS(texture, filePath);
}

void SaveTextureAsDDS(ID3D11Resource* texture, const wchar* filePath)
{
    ID3D11DevicePtr device;
    texture->GetDevice(&device);

    ID3D11DeviceContextPtr context;
    device->GetImmediateContext(&context);

    ScratchImage scratchImage;
    DXCall(CaptureTexture(device, context, texture, scratchImage));
    DXCall(SaveToDDSFile(scratchImage.GetImages(), scratchImage.GetImageCount(),
                         scratchImage.GetMetadata(), DDS_FLAGS_FORCE_DX10_EXT, filePath));
}

void SaveTextureAsEXR(ID3D11ShaderResourceView* srv, const wchar* filePath)
{
    ID3D11DevicePtr device;
    srv->GetDevice(&device);

    TextureData<Float4> textureData;
    GetTextureData(device, srv, textureData);

    SaveTextureAsEXR(textureData, filePath);
}

void SaveTextureAsEXR(const TextureData<Float4>& texture, const wchar* filePath)
{
    Assert_(texture.Texels.size() > 0);
    Assert_(texture.Width > 0 && texture.Height > 0);
    Assert_(texture.NumSlices == 1);

    const uint64 numTexels = texture.Texels.size();
    std::vector<float> channelDataR;
    std::vector<float> channelDataG;
    std::vector<float> channelDataB;
    channelDataR.resize(numTexels);
    channelDataG.resize(numTexels);
    channelDataB.resize(numTexels);
    for(uint64 i = 0; i < numTexels; ++i)
    {
        channelDataR[i] = texture.Texels[i].x;
        channelDataG[i] = texture.Texels[i].y;
        channelDataB[i] = texture.Texels[i].z;
    }

    float* imageChannels[3] = { channelDataB.data(), channelDataG.data(), channelDataR.data() };
    const char* channelNames[3] = { "B", "G", "R" };

    EXRImage exrImage;
    exrImage.num_channels = 3;
    exrImage.width = texture.Width;
    exrImage.height = texture.Height;
    exrImage.channel_names = channelNames;
    exrImage.images = imageChannels;

    std::string filePathAnsi = WStringToAnsi(filePath);

    const char* errorString = nullptr;
    int returnCode = SaveMultiChannelEXR(&exrImage, filePathAnsi.c_str(), &errorString);
    if(returnCode != 0)
    {
        AssertFail_("%s", errorString);
        throw Exception(AnsiToWString(errorString));
    }
}

void SaveTextureAsPNG(ID3D11ShaderResourceView* srv, const wchar* filePath)
{
    ID3D11ResourcePtr texture;
    srv->GetResource(&texture);

    SaveTextureAsPNG(texture, filePath);
}

void SaveTextureAsPNG(ID3D11Resource* texture, const wchar* filePath)
{
    ID3D11DevicePtr device;
    texture->GetDevice(&device);

    ID3D11DeviceContextPtr context;
    device->GetImmediateContext(&context);

    ScratchImage scratchImage;
    DXCall(CaptureTexture(device, context, texture, scratchImage));

    DXCall(SaveToWICFile(scratchImage.GetImages(), scratchImage.GetImageCount(), WIC_FLAGS_NONE,
                         GetWICCodec(WIC_CODEC_PNG), filePath));
}

// Utility function to map a XY + Side coordinate to a direction vector
Float3 MapXYSToDirection(uint64 x, uint64 y, uint64 s, uint64 width, uint64 height)
{
    float u = ((x + 0.5f) / float(width)) * 2.0f - 1.0f;
    float v = ((y + 0.5f) / float(height)) * 2.0f - 1.0f;
    v *= -1.0f;

    Float3 dir = 0.0f;

    // +x, -x, +y, -y, +z, -z
    switch(s) {
    case 0:
        dir = Float3::Normalize(Float3(1.0f, v, -u));
        break;
    case 1:
        dir = Float3::Normalize(Float3(-1.0f, v, u));
        break;
    case 2:
        dir = Float3::Normalize(Float3(u, 1.0f, -v));
        break;
    case 3:
        dir = Float3::Normalize(Float3(u, -1.0f, v));
        break;
    case 4:
        dir = Float3::Normalize(Float3(u, v, 1.0f));
        break;
    case 5:
        dir = Float3::Normalize(Float3(-u, v, -1.0f));
        break;
    }

    return dir;
}

}