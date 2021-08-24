//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "Skybox.h"

#include "..\\Utility.h"
#include "..\\HosekSky\\ArHosekSkyModel.h"
#include "ShaderCompilation.h"
#include "Textures.h"
#include "Math.h"

namespace SampleFramework11
{

static float AngleBetween(const Float3& dir0, const Float3& dir1)
{
    return std::acos(std::max(Float3::Dot(dir0, dir1), 0.00001f));
}

void SkyCache::Init(Float3 sunDirection, Float3 groundAlbedo, float turbidity)
{
    sunDirection.y = Saturate(sunDirection.y);
    sunDirection = Float3::Normalize(sunDirection);
    turbidity = Clamp(turbidity, 1.0f, 32.0f);
    groundAlbedo = Saturate(groundAlbedo);

    if(StateR != nullptr && sunDirection == SunDirection
        && groundAlbedo == Albedo && turbidity == Turbidity)
        return;

    Shutdown();

    float thetaS = AngleBetween(sunDirection, Float3(0, 1, 0));
    float elevation = Pi_2 - thetaS;
    StateR = arhosek_rgb_skymodelstate_alloc_init(turbidity, groundAlbedo.x, elevation);
    StateG = arhosek_rgb_skymodelstate_alloc_init(turbidity, groundAlbedo.y, elevation);
    StateB = arhosek_rgb_skymodelstate_alloc_init(turbidity, groundAlbedo.z, elevation);

    Albedo = groundAlbedo;
    Elevation = elevation;
    SunDirection = sunDirection;
    Turbidity = turbidity;
}

void SkyCache::Shutdown()
{
    if(StateR != nullptr)
    {
        arhosekskymodelstate_free(StateR);
        StateR = nullptr;
    }

    if(StateG != nullptr)
    {
        arhosekskymodelstate_free(StateG);
        StateG = nullptr;
    }

    if(StateB != nullptr)
    {
        arhosekskymodelstate_free(StateB);
        StateB = nullptr;
    }

    CubeMap = nullptr;
    Turbidity = 0.0f;
    Albedo = 0.0f;
    Elevation = 0.0f;
    SunDirection = 0.0f;
}

SkyCache::~SkyCache()
{
    Shutdown();
}

Skybox::Skybox()
{
}

Skybox::~Skybox()
{
}

void Skybox::Initialize(ID3D11Device* device_)
{
    device = device_;

    // Load the shaders
    const std::wstring shaderPath = SampleFrameworkDir() + L"Shaders\\Skybox.hlsl";
    vertexShader = CompileVSFromFile(device, shaderPath.c_str(), "SkyboxVS", "vs_5_0");
    emPixelShader = CompilePSFromFile(device, shaderPath.c_str(), "SkyboxPS", "ps_5_0");
    simpleSkyPS = CompilePSFromFile(device, shaderPath.c_str(), "SimpleSkyPS", "ps_5_0");

    // Create the input layout
    D3D11_INPUT_ELEMENT_DESC layout[] =
    {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    };

    ID3DBlob* byteCode = vertexShader->ByteCode;
    DXCall(device->CreateInputLayout(layout, 1, byteCode->GetBufferPointer(), byteCode->GetBufferSize(), &inputLayout));

    // Create and initialize the vertex and index buffers
    Float3 verts[NumVertices] =
    {
        Float3(-1, 1, 1),
        Float3(1, 1, 1),
        Float3(1, -1, 1),
        Float3(-1, -1, 1),
        Float3(1, 1, -1),
        Float3(-1, 1, -1),
        Float3(-1, -1, -1),
        Float3(1, -1,- 1),
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
    DXCall(device->CreateBuffer(&desc, &initData, &vertexBuffer));

    unsigned short indices[NumIndices] =
    {
        0, 1, 2, 2, 3, 0,   // Front
        1, 4, 7, 7, 2, 1,   // Right
        4, 5, 6, 6, 7, 4,   // Back
        5, 0, 3, 3, 6, 5,   // Left
        5, 4, 1, 1, 0, 5,   // Top
        3, 2, 7, 7, 6, 3    // Bottom
    };

    desc.Usage = D3D11_USAGE_IMMUTABLE;
    desc.ByteWidth = sizeof(indices);
    desc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    desc.CPUAccessFlags = 0;
    initData.pSysMem = indices;
    DXCall(device->CreateBuffer(&desc, &initData, &indexBuffer));

    // Create the VS constant buffer
    vsConstantBuffer.Initialize(device, false);

    // Create the PS constant buffer
    psConstantBuffer.Initialize(device, false);

    // Create a depth-stencil state
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = true;
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
    for (UINT i = 0; i < 8; ++i)
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

    D3D11_SAMPLER_DESC sampDesc;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
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
    DXCall(device->CreateSamplerState(&sampDesc, &samplerState));
}

void Skybox::RenderCommon(ID3D11DeviceContext* context,
                          ID3D11ShaderResourceView* environmentMap,
                          ID3D11PixelShader* ps,
                          const Float4x4& view,
                          const Float4x4& projection,
                          Float3 scale)
{
    float blendFactor[4] = {1, 1, 1, 1};
    context->RSSetState(rastState);
    context->OMSetBlendState(blendState, blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(dsState, 0);
    context->PSSetSamplers(0, 1, &(samplerState.GetInterfacePtr()));

    // Get the viewports
    UINT numViewports = D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE;
    D3D11_VIEWPORT oldViewports[D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE];
    context->RSGetViewports(&numViewports, oldViewports);

    // Set a viewport with MinZ pushed back
    D3D11_VIEWPORT newViewports[D3D11_VIEWPORT_AND_SCISSORRECT_OBJECT_COUNT_PER_PIPELINE];
    for(UINT i = 0; i < numViewports; ++i)
    {
        newViewports[i] = oldViewports[0];
        newViewports[i].MinDepth = 1.0f;
        newViewports[i].MaxDepth = 1.0f;
    }
    context->RSSetViewports(numViewports, newViewports);

    // Set the input layout
    context->IASetInputLayout(inputLayout);

    // Set the vertex buffer
    UINT stride = sizeof(XMFLOAT3);
    UINT offset = 0;
    ID3D11Buffer* vertexBuffers[1] = { vertexBuffer.GetInterfacePtr() };
    context->IASetVertexBuffers(0, 1, vertexBuffers, &stride, &offset);

    // Set the index buffer
    context->IASetIndexBuffer(indexBuffer, DXGI_FORMAT_R16_UINT, 0);

    // Set primitive topology
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    // Set the shaders
    context->VSSetShader(vertexShader, nullptr, 0);
    context->PSSetShader(ps, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->DSSetShader(nullptr, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);

    // Set the constants
    vsConstantBuffer.Data.View = Float4x4::Transpose(view);
    vsConstantBuffer.Data.Projection = Float4x4::Transpose(projection);
    vsConstantBuffer.ApplyChanges(context);
    vsConstantBuffer.SetVS(context, 0);

    psConstantBuffer.Data.Scale = scale;
    psConstantBuffer.ApplyChanges(context);
    psConstantBuffer.SetPS(context, 0);

    // Set the texture
    ID3D11ShaderResourceView* srViews[1] = { environmentMap };
    context->PSSetShaderResources(0, 1, srViews);

    // Draw
    context->DrawIndexed(NumIndices, 0, 0);

    // Set the viewport back to what it was
    context->RSSetViewports(numViewports, oldViewports);
}

void Skybox::RenderEnvironmentMap(ID3D11DeviceContext* context,
                                  ID3D11ShaderResourceView* environmentMap,
                                  const Float4x4& view,
                                  const Float4x4& projection,
                                  Float3 scale)
{
    PIXEvent pixEvent(L"Skybox Render Environment Map");

    psConstantBuffer.Data.EnableSun = false;
    RenderCommon(context, environmentMap, emPixelShader, view, projection, scale);
}

void Skybox::RenderSky(ID3D11DeviceContext* context,
                       Float3 sunDirection,
                       Float3 groundAlbedo,
                       Float3 sunColor,
                       float sunSize,
                       float turbidity,
                       const Float4x4& view,
                       const Float4x4& projection,
                       Float3 scale)
{
    PIXEvent pixEvent(L"Skybox Render Sky");

    // Update the cache, if necessary
    skyCache.Init(sunDirection, groundAlbedo, turbidity);

    if(skyCache.CubeMap == nullptr)
    {
        const uint64 CubeMapRes = 128;
        std::vector<Half4> texels;
        texels.resize(CubeMapRes * CubeMapRes * 6);

        for(uint64 s = 0; s < 6; ++s)
        {
            for(uint64 y = 0; y < CubeMapRes; ++y)
            {
                for(uint64 x = 0; x < CubeMapRes; ++x)
                {
                    Float3 dir = MapXYSToDirection(x, y, s, CubeMapRes, CubeMapRes);
                    Float3 radiance = SampleSky(skyCache, dir);

                    uint64 idx = (s * CubeMapRes * CubeMapRes) + (y * CubeMapRes) + x;
                    texels[idx] = Half4(Float4(radiance, 1.0f));
                }
            }
        }

        D3D11_TEXTURE2D_DESC desc;
        desc.Width = uint32(CubeMapRes);
        desc.Height = uint32(CubeMapRes);
        desc.ArraySize = 6;
        desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
        desc.CPUAccessFlags = 0;
        desc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT;
        desc.MipLevels = 1;
        desc.MiscFlags = D3D11_RESOURCE_MISC_TEXTURECUBE;
        desc.SampleDesc.Count = 1;
        desc.SampleDesc.Quality = 0;
        desc.Usage = D3D11_USAGE_IMMUTABLE;

        D3D11_SUBRESOURCE_DATA resData[6];
        for(uint64 i = 0; i < 6; ++i)
        {
            resData[i].pSysMem = &texels[i * CubeMapRes * CubeMapRes];
            resData[i].SysMemPitch = sizeof(texels[0]) * CubeMapRes;
            resData[i].SysMemSlicePitch = 0;
        }

        ID3D11DevicePtr device;
        context->GetDevice(&device);

        ID3D11Texture2DPtr texture;
        DXCall(device->CreateTexture2D(&desc, resData, &texture));
        DXCall(device->CreateShaderResourceView(texture, nullptr, &skyCache.CubeMap));
    }

    // Set the pixel shader constants
    bool enableSun = sunSize > 0.0f && sunColor.x > 0.0f && sunColor.y > 0.0f && sunColor.z > 0.0f;
    psConstantBuffer.Data.SunDirection = sunDirection;
    psConstantBuffer.Data.EnableSun = enableSun ? 1 : 0;
    psConstantBuffer.Data.SunColor = sunColor;
    psConstantBuffer.Data.Scale = scale;
    psConstantBuffer.Data.CosSunAngularRadius = std::cos(DegToRad(sunSize));

    RenderCommon(context, skyCache.CubeMap, emPixelShader, view, projection, scale);
}

void Skybox::RenderSimpleSky(ID3D11DeviceContext* context,
                             Float3 skyColor,
                             Float3 sunDirection,
                             Float3 sunColor,
                             float sunSize,
                             const Float4x4& view,
                             const Float4x4& projection,
                             Float3 scale)
{
    PIXEvent pixEvent(L"Skybox Render Simple Sky");

    // Set the pixel shader constants
    bool enableSun = sunSize > 0.0f && sunColor.x > 0.0f && sunColor.y > 0.0f && sunColor.z > 0.0f;
    psConstantBuffer.Data.SkyColor = skyColor;
    psConstantBuffer.Data.SunDirection = sunDirection;
    psConstantBuffer.Data.EnableSun = enableSun ? 1 : 0;
    psConstantBuffer.Data.SunColor = sunColor;
    psConstantBuffer.Data.Scale = scale;
    psConstantBuffer.Data.CosSunAngularRadius = std::cos(DegToRad(sunSize));

    RenderCommon(context, nullptr, simpleSkyPS, view, projection, scale);
}

Float3 Skybox::SampleSky(const SkyCache& cache, Float3 sampleDir)
{
    Assert_(cache.StateR != nullptr);

    float gamma = AngleBetween(sampleDir, cache.SunDirection);
    float theta = AngleBetween(sampleDir, Float3(0, 1, 0));

    Float3 radiance;

    radiance.x = float(arhosek_tristim_skymodel_radiance(cache.StateR, theta, gamma, 0));
    radiance.y = float(arhosek_tristim_skymodel_radiance(cache.StateG, theta, gamma, 1));
    radiance.z = float(arhosek_tristim_skymodel_radiance(cache.StateB, theta, gamma, 2));

    // Multiply by standard luminous efficacy of 683 lm/W to bring us in line with the photometric
    // units used during rendering
    radiance *= 683.0f;

    radiance *= FP16Scale;

    return radiance;
}

}
