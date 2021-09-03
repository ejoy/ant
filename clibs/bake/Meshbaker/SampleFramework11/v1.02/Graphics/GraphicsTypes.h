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
#include "..\\Utility.h"

namespace SampleFramework11
{

struct RenderTarget2D
{
    ID3D11Texture2DPtr Texture;
    ID3D11RenderTargetViewPtr RTView;
    ID3D11ShaderResourceViewPtr SRView;
    ID3D11UnorderedAccessViewPtr UAView;
    uint32 Width;
    uint32 Height;
    uint32 NumMipLevels;
    uint32 MultiSamples;
    uint32 MSQuality;
    DXGI_FORMAT Format;
    bool32 AutoGenMipMaps;
    uint32 ArraySize;
    bool32 CubeMap;
    std::vector<ID3D11RenderTargetViewPtr> RTVArraySlices;
    std::vector<ID3D11ShaderResourceViewPtr> SRVArraySlices;

    RenderTarget2D();

  void Initialize(      ID3D11Device* device,
                        uint32 width,
                        uint32 height,
                        DXGI_FORMAT format,
                        uint32 numMipLevels = 1,
                        uint32 multiSamples = 1,
                        uint32 msQuality = 0,
                        bool32 autoGenMipMaps = false,
                        bool32 createUAV = false,
                        uint32 arraySize = 1,
                        bool32 cubeMap = false);
};

struct DepthStencilBuffer
{
    ID3D11Texture2DPtr Texture;
    ID3D11DepthStencilViewPtr DSView;
    ID3D11DepthStencilViewPtr ReadOnlyDSView;
    ID3D11ShaderResourceViewPtr SRView;
    uint32 Width;
    uint32 Height;
    uint32 MultiSamples;
    uint32 MSQuality;
    DXGI_FORMAT Format;
    uint32 ArraySize;
    bool32 CubeMap;
    std::vector<ID3D11DepthStencilViewPtr> ArraySlices;

    DepthStencilBuffer();

    void Initialize(    ID3D11Device* device,
                        uint32 width,
                        uint32 height,
                        DXGI_FORMAT format = DXGI_FORMAT_D24_UNORM_S8_UINT,
                        bool32 useAsShaderResource = false,
                        uint32 multiSamples = 1,
                        uint32 msQuality = 0,
                        uint32 arraySize = 1,
                        bool32 cubeMap = false);
};

struct RWBuffer
{
    ID3D11BufferPtr Buffer;
    ID3D11ShaderResourceViewPtr SRView;
    ID3D11UnorderedAccessViewPtr UAView;
    uint32 Size;
    uint32 Stride;
    uint32 NumElements;
    bool32 RawBuffer;
    DXGI_FORMAT Format;

    RWBuffer();

    void Initialize(ID3D11Device* device, DXGI_FORMAT format, uint32 stride, uint32 numElements, bool32 rawBuffer = false,
                    bool vertexBuffer = false, bool indexBuffer = false, bool indirectArgs = false,
                    const void* initData = nullptr);
};

struct StagingBuffer
{
    ID3D11BufferPtr Buffer;
    uint32 Size;

    StagingBuffer();

    void Initialize(ID3D11Device* device, uint32 size);
    void* Map(ID3D11DeviceContext* context);
    void Unmap(ID3D11DeviceContext* context);
};

struct StagingTexture2D
{
    ID3D11Texture2DPtr Texture;
    uint32 Width;
    uint32 Height;
    uint32 NumMipLevels;
    uint32 MultiSamples;
    uint32 MSQuality;
    DXGI_FORMAT Format;
    uint32 ArraySize;

    StagingTexture2D();

    void Initialize(    ID3D11Device* device,
                        uint32 width,
                        uint32 height,
                        DXGI_FORMAT format,
                        uint32 numMipLevels = 1,
                        uint32 multiSamples = 1,
                        uint32 msQuality = 0,
                        uint32 arraySize = 1);

    void* Map(ID3D11DeviceContext* context, uint32 subResourceIndex, uint32& pitch);
    void Unmap(ID3D11DeviceContext* context, uint32 subResourceIndex);
};

struct StructuredBuffer
{
    ID3D11BufferPtr Buffer;
    ID3D11ShaderResourceViewPtr SRView;
    ID3D11UnorderedAccessViewPtr UAView;
    uint32 Size;
    uint32 Stride;
    uint32 NumElements;
    StagingBuffer DebugBuffer;

    StructuredBuffer();

    void Initialize(ID3D11Device* device, uint32 stride, uint32 numElements, bool32 useAsUAV = false,
                    bool32 appendConsume = false, bool32 hiddenCounter = false, const void* initData = nullptr);

    void WriteToFile(const wchar* path, ID3D11Device* device, ID3D11DeviceContext* context);
    void ReadFromFile(const wchar* path, ID3D11Device* device);

    template<typename T> void DebugPrint(ID3D11DeviceContext* context, const char* name)
    {
        Assert_(Buffer != nullptr);
        if(DebugBuffer.Size != Size)
        {
            ID3D11DevicePtr device;
            context->GetDevice(&device);
            DebugBuffer.Initialize(device, Size);
        }

        std::printf("%s\n", name);

        context->CopyResource(DebugBuffer.Buffer, Buffer);
        const T* data = reinterpret_cast<T*>(DebugBuffer.Map(context));
        for(uint32 i = 0; i < NumElements; ++i)
        {
            std::string elemPrint = data[i].Print();
            std::printf("    [%u] %s", i, elemPrint.c_str());
        }
    }
};

template<typename T> class ConstantBuffer
{
public:

    T Data;

    ID3D11BufferPtr Buffer;
    bool GPUWritable;

public:

    ConstantBuffer() : GPUWritable(false)
    {
        ZeroMemory(&Data, sizeof(T));
    }

    void Initialize(ID3D11Device* device, bool gpuWritable = false)
    {
        D3D11_BUFFER_DESC desc;
        desc.Usage = D3D11_USAGE_DYNAMIC;
        desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
        desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
        desc.MiscFlags = 0;
        desc.ByteWidth = static_cast<uint32>(sizeof(T) + (16 - (sizeof(T) % 16)));

        if(gpuWritable)
        {
            desc.Usage = D3D11_USAGE_DEFAULT;
            desc.CPUAccessFlags = 0;
        }
        GPUWritable = gpuWritable;

        DXCall(device->CreateBuffer(&desc, nullptr, &Buffer));
    }

    void ApplyChanges(ID3D11DeviceContext* deviceContext)
    {
        Assert_(Buffer != nullptr);

        if(GPUWritable)
        {
            deviceContext->UpdateSubresource(Buffer, 0, nullptr, &Data, 0, 0);
        }
        else
        {
            D3D11_MAPPED_SUBRESOURCE mappedResource;
            DXCall(deviceContext->Map(Buffer, 0, D3D11_MAP_WRITE_DISCARD, 0, &mappedResource));
            CopyMemory(mappedResource.pData, &Data, sizeof(T));
            deviceContext->Unmap(Buffer, 0);
        }
    }

    void SetVS(ID3D11DeviceContext* deviceContext, uint32 slot) const
    {
        Assert_(Buffer != nullptr);

        ID3D11Buffer* bufferArray[1];
        bufferArray[0] = Buffer;
        deviceContext->VSSetConstantBuffers(slot, 1, bufferArray);
    }

    void SetPS(ID3D11DeviceContext* deviceContext, uint32 slot) const
    {
        Assert_(Buffer != nullptr);

        ID3D11Buffer* bufferArray[1];
        bufferArray[0] = Buffer;
        deviceContext->PSSetConstantBuffers(slot, 1, bufferArray);
    }

    void SetGS(ID3D11DeviceContext* deviceContext, uint32 slot) const
    {
        Assert_(Buffer != nullptr);

        ID3D11Buffer* bufferArray[1];
        bufferArray[0] = Buffer;
        deviceContext->GSSetConstantBuffers(slot, 1, bufferArray);
    }

    void SetHS(ID3D11DeviceContext* deviceContext, uint32 slot) const
    {
        Assert_(Buffer != nullptr);

        ID3D11Buffer* bufferArray[1];
        bufferArray[0] = Buffer;
        deviceContext->HSSetConstantBuffers(slot, 1, bufferArray);
    }

    void SetDS(ID3D11DeviceContext* deviceContext, uint32 slot) const
    {
        Assert_(Buffer != nullptr);

        ID3D11Buffer* bufferArray[1];
        bufferArray[0] = Buffer;
        deviceContext->DSSetConstantBuffers(slot, 1, bufferArray);
    }

    void SetCS(ID3D11DeviceContext* deviceContext, uint32 slot) const
    {
        Assert_(Buffer != nullptr);

        ID3D11Buffer* bufferArray[1];
        bufferArray[0] = Buffer;
        deviceContext->CSSetConstantBuffers(slot, 1, bufferArray);
    }
};

// For aligning to float4 boundaries
#define Float4Align __declspec(align(16))

class PIXEvent
{
public:

    PIXEvent(const wchar* markerName)
    {
        D3DPERF_BeginEvent(0xFFFFFFFF, markerName);
    }

    PIXEvent(const std::wstring& markerName)
    {
        D3DPERF_BeginEvent(0xFFFFFFFF, markerName.c_str());
    }

    ~PIXEvent()
    {
       D3DPERF_EndEvent();
    }
};

}