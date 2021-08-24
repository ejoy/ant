//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "PostProcessorBase.h"

#include "..\\Utility.h"
#include "ShaderCompilation.h"

namespace SampleFramework11
{

PostProcessorBase::PostProcessorBase() : device(nullptr), context(nullptr)
{
}

PostProcessorBase::~PostProcessorBase()
{
    ClearTempRenderTargetCache();
}

void PostProcessorBase::Initialize(ID3D11Device* device)
{
    this->device = device;

    // Create resources for the full-screen quad

    // Load the shaders
    std::wstring quadPath = SampleFrameworkDir() + L"Shaders\\Quad.hlsl";
    quadVS = CompileVSFromFile(device, quadPath.c_str(), "QuadVS");

    // Create the input layout
    D3D11_INPUT_ELEMENT_DESC layout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, D3D11_APPEND_ALIGNED_ELEMENT, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };

    DXCall(device->CreateInputLayout(layout, 2, quadVS->ByteCode->GetBufferPointer(),
                                     quadVS->ByteCode->GetBufferSize(), &quadInputLayout));

    // Create and initialize the vertex and index buffers
    QuadVertex verts[4] =
    {
        { XMFLOAT4(1, 1, 1, 1), XMFLOAT2(1, 0) },
        { XMFLOAT4(1, -1, 1, 1), XMFLOAT2(1, 1) },
        { XMFLOAT4(-1, -1, 1, 1), XMFLOAT2(0, 1) },
        { XMFLOAT4(-1, 1, 1, 1), XMFLOAT2(0, 0) }
    };

    D3D11_BUFFER_DESC desc;
    desc.Usage = D3D11_USAGE_IMMUTABLE;
    desc.ByteWidth = sizeof(verts);
    desc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    desc.CPUAccessFlags = 0;
    desc.MiscFlags = 0;
    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = verts;
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&desc, &initData, &quadVB));

    unsigned short indices[6] = { 0, 1, 2, 2, 3, 0 };

    desc.Usage = D3D11_USAGE_IMMUTABLE;
    desc.ByteWidth = sizeof(indices);
    desc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    desc.CPUAccessFlags = 0;
    initData.pSysMem = indices;
    DXCall(device->CreateBuffer(&desc, &initData, &quadIB));

    // Create the constant buffer
    desc.Usage = D3D11_USAGE_DYNAMIC;
    desc.ByteWidth = CBSize(sizeof(PSConstants));
    desc.BindFlags = D3D11_BIND_CONSTANT_BUFFER;
    desc.CPUAccessFlags = D3D11_CPU_ACCESS_WRITE;
    DXCall(device->CreateBuffer(&desc, nullptr, &psConstants));

    // Create a depth-stencil state
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = false;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ZERO;
    dsDesc.DepthFunc = D3D11_COMPARISON_LESS_EQUAL;
    dsDesc.StencilEnable = false;
    dsDesc.StencilReadMask = D3D11_DEFAULT_STENCIL_READ_MASK;
    dsDesc.StencilWriteMask = D3D11_DEFAULT_STENCIL_WRITE_MASK;
    dsDesc.FrontFace.StencilDepthFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilPassOp = D3D11_STENCIL_OP_REPLACE;
    dsDesc.FrontFace.StencilFunc = D3D11_COMPARISON_ALWAYS;
    dsDesc.BackFace = dsDesc.FrontFace;
    DXCall(device->CreateDepthStencilState(&dsDesc, &dsState));

    // Create a blend state
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = false;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = false;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }
    DXCall(device->CreateBlendState(&blendDesc, &blendState));

    // Create a rasterizer state
    D3D11_RASTERIZER_DESC rastDesc;
    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_NONE;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = false;
    rastDesc.SlopeScaledDepthBias = 0;
    DXCall(device->CreateRasterizerState(&rastDesc, &rastState));

    // Create sampler states
    D3D11_SAMPLER_DESC sampDesc;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.BorderColor[0] = 0;
    sampDesc.BorderColor[1] = 0;
    sampDesc.BorderColor[2] = 0;
    sampDesc.BorderColor[3] = 0;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
    sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;
    sampDesc.MinLOD = 0;
    sampDesc.MipLODBias = 0;
    DXCall(device->CreateSamplerState(&sampDesc, &linearSamplerState));

    sampDesc.AddressU = sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
    DXCall(device->CreateSamplerState(&sampDesc, &linearWrapSamplerState));

    sampDesc.AddressU = sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_BORDER;
    DXCall(device->CreateSamplerState(&sampDesc, &linearBorderSamplerState));

    sampDesc.AddressU = sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_POINT;
    DXCall(device->CreateSamplerState(&sampDesc, &pointSamplerState));

    sampDesc.AddressU = sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_BORDER;
    DXCall(device->CreateSamplerState(&sampDesc, &pointBorderSamplerState));
}

void PostProcessorBase::AfterReset(uint32 width, uint32 height)
{
    // Clear all of the temp render targets
    ClearTempRenderTargetCache();

    inputWidth = width;
    inputHeight = height;
}

void PostProcessorBase::Render(ID3D11DeviceContext* deviceContext, ID3D11ShaderResourceView* input, ID3D11RenderTargetView* output)
{
    context = deviceContext;

    // Set device states
    float blendFactor[4] = {1, 1, 1, 1};
    context->RSSetState(rastState);
    context->OMSetBlendState(blendState, blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(dsState, 0);

    // Set the sampler states
    ID3D11SamplerState* samplerStates[5] = { pointSamplerState, linearSamplerState,
                                             linearWrapSamplerState, linearBorderSamplerState,
                                             pointBorderSamplerState };
    context->PSSetSamplers(0, 5, samplerStates);

    // Set the input layout
    context->IASetInputLayout(quadInputLayout);

    // Set the vertex buffer
    uint32 stride = sizeof(QuadVertex);
    uint32 offset = 0;
    ID3D11Buffer* vertexBuffers[1] = { quadVB.GetInterfacePtr() };
    context->IASetVertexBuffers(0, 1, vertexBuffers, &stride, &offset);

    // Set the index buffer
    context->IASetIndexBuffer(quadIB, DXGI_FORMAT_R16_UINT, 0);

    // Set primitive topology
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    // Set the shaders
    context->VSSetShader(quadVS, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->DSSetShader(nullptr, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);
}

void PostProcessorBase::PostProcess(ID3D11ShaderResourceView* input, ID3D11RenderTargetView* output, ID3D11PixelShader* pixelShader, const wchar* name)
{
    inputs.push_back(input);
    outputs.push_back(output);
    PostProcess(pixelShader, name);
}

void PostProcessorBase::PostProcess(ID3D11PixelShader* pixelShader, const wchar* name)
{
    Assert_(context);

    Assert_(inputs.size() <= MaxInputs);

    D3DPERF_BeginEvent(0xFFFFFFFF, name);

    // Set the outputs
    ID3D11RenderTargetView** renderTargets = reinterpret_cast<ID3D11RenderTargetView**>(&outputs[0]);
    uint32 numRTs = static_cast<uint32>(outputs.size());
    if(uaViews.size() == 0)
        context->OMSetRenderTargets(numRTs, renderTargets, nullptr);
    else
    {
        ID3D11UnorderedAccessView** uavs = reinterpret_cast<ID3D11UnorderedAccessView**>(&uaViews[0]);
        UINT numUAVs = static_cast<uint32>(uaViews.size());
        UINT initialCounts[D3D11_PS_CS_UAV_REGISTER_COUNT] = { 0 };
        context->OMSetRenderTargetsAndUnorderedAccessViews(numRTs, renderTargets, nullptr, numRTs, numUAVs, uavs, initialCounts);
    }

    // Set the input textures
    ID3D11ShaderResourceView** textures = reinterpret_cast<ID3D11ShaderResourceView**>(&inputs[0]);
    context->PSSetShaderResources(0, static_cast<uint32>(inputs.size()), textures);

    // Set the constants
    D3D11_MAPPED_SUBRESOURCE mapped;
    DXCall(context->Map(psConstants, 0, D3D11_MAP_WRITE_DISCARD, 0, &mapped));
    PSConstants* constants = reinterpret_cast<PSConstants*>(mapped.pData);

    for (size_t i = 0; i < inputs.size(); ++i)
    {
        if(inputs[i] == nullptr)
        {
            constants->InputSize[i].x = 0.0f;
            constants->InputSize[i].y = 0.0f;
            continue;
        }

        ID3D11Resource* resource;
        ID3D11Texture2DPtr texture;
        D3D11_TEXTURE2D_DESC desc;
        D3D11_SHADER_RESOURCE_VIEW_DESC srDesc;
        inputs[i]->GetDesc(&srDesc);
        uint32 mipLevel = srDesc.Texture2D.MostDetailedMip;
        inputs[i]->GetResource(&resource);
        texture.Attach(reinterpret_cast<ID3D11Texture2D*>(resource));
        texture->GetDesc(&desc);
        constants->InputSize[i].x = static_cast<float>(std::max<uint32>(desc.Width / (1 << mipLevel), 1));
        constants->InputSize[i].y = static_cast<float>(std::max<uint32>(desc.Height / (1 << mipLevel), 1));
    }

    ID3D11Resource* resource;
    ID3D11Texture2DPtr texture;
    D3D11_TEXTURE2D_DESC desc;
    D3D11_RENDER_TARGET_VIEW_DESC rtDesc;
    outputs[0]->GetResource(&resource);
    outputs[0]->GetDesc(&rtDesc);
    uint32 mipLevel = rtDesc.Texture2D.MipSlice;
    texture.Attach(reinterpret_cast<ID3D11Texture2D*>(resource));
    texture->GetDesc(&desc);
    constants->OutputSize.x = static_cast<float>(std::max<uint32>(desc.Width / (1 << mipLevel), 1));
    constants->OutputSize.y = static_cast<float>(std::max<uint32>(desc.Height / (1 << mipLevel), 1));

    context->Unmap(psConstants, 0);

    ID3D11Buffer* constantBuffers[1] = { psConstants };
    context->PSSetConstantBuffers(0, 1, constantBuffers);

    // Set the viewports
    D3D11_VIEWPORT viewports[16];
    for (UINT_PTR i = 0; i < 16; ++i)
    {
        viewports[i].Width = static_cast<float>(std::max<uint32>(desc.Width / (1 << mipLevel), 1));
        viewports[i].Height = static_cast<float>(std::max<uint32>(desc.Height / (1 << mipLevel), 1));
        viewports[i].TopLeftX = 0;
        viewports[i].TopLeftY = 0;
        viewports[i].MinDepth = 0.0f;
        viewports[i].MaxDepth = 1.0f;
    }
    context->RSSetViewports(static_cast<uint32>(outputs.size()), viewports);

    // Set the pixel shader
    context->PSSetShader(pixelShader, nullptr, 0);

    // Draw the quad
    context->DrawIndexed(6, 0, 0);

    // Clear the SRV's and RT's
    ID3D11ShaderResourceView* srViews[16] = { nullptr };
    context->PSSetShaderResources(0, static_cast<uint32>(inputs.size()), srViews);

    ID3D11RenderTargetView* rtViews[16] = { nullptr };
    context->OMSetRenderTargets(static_cast<uint32>(outputs.size() + uaViews.size()), rtViews, nullptr);

    inputs.clear();
    outputs.clear();
    uaViews.clear();

    texture = nullptr;
    D3DPERF_EndEvent();
}

TempRenderTarget* PostProcessorBase::GetTempRenderTarget(uint32 width, uint32 height, DXGI_FORMAT format,
                                                         uint32 msCount, uint32 msQuality, uint32 mipLevels,
                                                         bool generateMipMaps, bool useAsUAV)
{
    // Look through existing render targets
    for (size_t i = 0; i < tempRenderTargets.size(); ++i)
    {
        TempRenderTarget* rt = tempRenderTargets[i];
        if (!rt->InUse && rt->Width == width && rt->Height == height && rt->Format == format
                && rt->MSCount == msCount && rt->MSQuality == msQuality && (rt->UAView != nullptr) == useAsUAV)
        {
            rt->InUse = true;
            return rt;
        }
    }

    // Didn't find one, have to make one
    TempRenderTarget* rt = new TempRenderTarget();
    D3D11_TEXTURE2D_DESC desc;
    desc.Width = width;
    desc.Height = height;
    desc.ArraySize = 1;
    desc.BindFlags = D3D11_BIND_SHADER_RESOURCE|D3D11_BIND_RENDER_TARGET;
    if(useAsUAV)
        desc.BindFlags |= D3D11_BIND_UNORDERED_ACCESS;
    desc.CPUAccessFlags = 0;
    desc.Format = format;
    desc.MipLevels = mipLevels;
    desc.MiscFlags = generateMipMaps ? D3D11_RESOURCE_MISC_GENERATE_MIPS : 0;
    desc.SampleDesc.Count = msCount;
    desc.SampleDesc.Quality = msQuality;
    desc.Usage = D3D11_USAGE_DEFAULT;
    DXCall(device->CreateTexture2D(&desc, nullptr, &rt->Texture));
    DXCall(device->CreateRenderTargetView(rt->Texture, nullptr, &rt->RTView));
    DXCall(device->CreateShaderResourceView(rt->Texture, nullptr, &rt->SRView));

    if(useAsUAV)
        device->CreateUnorderedAccessView(rt->Texture, nullptr, &rt->UAView);
    else
        rt->UAView = nullptr;

    rt->Width = width;
    rt->Height = height;
    rt->MSCount = msCount;
    rt->MSQuality = msQuality;
    rt->Format = format;
    rt->InUse = true;
    tempRenderTargets.push_back(rt);

    return tempRenderTargets[tempRenderTargets.size() - 1];
}

void PostProcessorBase::ClearTempRenderTargetCache()
{
    for (size_t i = 0; i < tempRenderTargets.size(); ++i)
    {
        tempRenderTargets[i]->SRView->Release();
        tempRenderTargets[i]->RTView->Release();
        tempRenderTargets[i]->Texture->Release();
        if(tempRenderTargets[i]->UAView)
            tempRenderTargets[i]->UAView->Release();
        delete tempRenderTargets[i];
    }

    tempRenderTargets.erase(tempRenderTargets.begin(), tempRenderTargets.end());
}

}