//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "DeviceStates.h"
#include "..\\Utility.h"

namespace SampleFramework11
{

void BlendStates::Initialize(ID3D11Device* device)
{
    auto bd_dsec = BlendDisabledDesc();
    DXCall(device->CreateBlendState(&bd_dsec, &blendDisabled));
    auto ab_desc = AdditiveBlendDesc();
    DXCall(device->CreateBlendState(&ab_desc, &additiveBlend));
    auto alpha_desc = AlphaBlendDesc();
    DXCall(device->CreateBlendState(&alpha_desc, &alphaBlend));
    auto pm_desc = PreMultipliedAlphaBlendDesc();
    DXCall(device->CreateBlendState(&pm_desc, &pmAlphaBlend));
    auto cwd_desc = ColorWriteDisabledDesc();
    DXCall(device->CreateBlendState(&cwd_desc, &noColor));
    auto ac_desc = AlphaToCoverageDesc();
    DXCall(device->CreateBlendState(&ac_desc, &alphaToCoverage));
    auto op_desc = OpacityBlendDesc();
    DXCall(device->CreateBlendState(&op_desc, &opacityBlend));
}

D3D11_BLEND_DESC BlendStates::BlendDisabledDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = false;
    for(UINT i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = false;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_SRC_ALPHA;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    return blendDesc;
}

D3D11_BLEND_DESC BlendStates::AdditiveBlendDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = false;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = true;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    return blendDesc;
}

D3D11_BLEND_DESC BlendStates::AlphaBlendDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = true;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = true;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_SRC_ALPHA;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    blendDesc.RenderTarget[0].BlendEnable = true;

    return blendDesc;
}

D3D11_BLEND_DESC BlendStates::PreMultipliedAlphaBlendDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = false;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = false;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    return blendDesc;
}

D3D11_BLEND_DESC BlendStates::ColorWriteDisabledDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = false;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = false;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = 0;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_SRC_ALPHA;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    return blendDesc;
}

D3D11_BLEND_DESC BlendStates::AlphaToCoverageDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = true;
    blendDesc.IndependentBlendEnable = false;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = false;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_INV_SRC_ALPHA;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_SRC_ALPHA;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    return blendDesc;
}

D3D11_BLEND_DESC BlendStates::OpacityBlendDesc()
{
    D3D11_BLEND_DESC blendDesc;
    blendDesc.AlphaToCoverageEnable = false;
    blendDesc.IndependentBlendEnable = false;
    for (uint32 i = 0; i < 8; ++i)
    {
        blendDesc.RenderTarget[i].BlendEnable = true;
        blendDesc.RenderTarget[i].BlendOp = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].BlendOpAlpha = D3D11_BLEND_OP_ADD;
        blendDesc.RenderTarget[i].DestBlend = D3D11_BLEND_INV_SRC1_COLOR;
        blendDesc.RenderTarget[i].DestBlendAlpha = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].RenderTargetWriteMask = D3D11_COLOR_WRITE_ENABLE_ALL;
        blendDesc.RenderTarget[i].SrcBlend = D3D11_BLEND_ONE;
        blendDesc.RenderTarget[i].SrcBlendAlpha = D3D11_BLEND_ONE;
    }

    return blendDesc;
}

void RasterizerStates::Initialize(ID3D11Device* device)
{
    D3D11_RASTERIZER_DESC rd = NoCullDesc();
    DXCall(device->CreateRasterizerState(&rd, &noCull));
    rd = FrontFaceCullDesc(); DXCall(device->CreateRasterizerState(&rd, &cullFrontFaces));
    rd = FrontFaceCullScissorDesc(); DXCall(device->CreateRasterizerState(&rd, &cullFrontFacesScissor));
    rd = BackFaceCullDesc(); DXCall(device->CreateRasterizerState(&rd, &cullBackFaces));
    rd = BackFaceCullScissorDesc(); DXCall(device->CreateRasterizerState(&rd, &cullBackFacesScissor));
    rd = BackFaceCullNoZClipDesc(); DXCall(device->CreateRasterizerState(&rd, &cullBackFacesNoZClip));
    rd = NoCullNoMSDesc(); DXCall(device->CreateRasterizerState(&rd, &noCullNoMS));
    rd = NoCullScissorDesc(); DXCall(device->CreateRasterizerState(&rd, &noCullScissor));
    rd = WireframeDesc(); DXCall(device->CreateRasterizerState(&rd, &wireframe));
}

D3D11_RASTERIZER_DESC RasterizerStates::NoCullDesc()
{
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

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::FrontFaceCullDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_FRONT;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = false;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::FrontFaceCullScissorDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_FRONT;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = true;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = true;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::BackFaceCullDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_BACK;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = false;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::BackFaceCullScissorDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_BACK;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = true;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::BackFaceCullNoZClipDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_BACK;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = false;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = false;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::NoCullNoMSDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_NONE;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = false;
    rastDesc.ScissorEnable = false;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::NoCullScissorDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_NONE;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_SOLID;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = true;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

D3D11_RASTERIZER_DESC RasterizerStates::WireframeDesc()
{
    D3D11_RASTERIZER_DESC rastDesc;

    rastDesc.AntialiasedLineEnable = false;
    rastDesc.CullMode = D3D11_CULL_NONE;
    rastDesc.DepthBias = 0;
    rastDesc.DepthBiasClamp = 0.0f;
    rastDesc.DepthClipEnable = true;
    rastDesc.FillMode = D3D11_FILL_WIREFRAME;
    rastDesc.FrontCounterClockwise = false;
    rastDesc.MultisampleEnable = true;
    rastDesc.ScissorEnable = false;
    rastDesc.SlopeScaledDepthBias = 0;

    return rastDesc;
}

void DepthStencilStates::Initialize(ID3D11Device* device)
{
    D3D11_DEPTH_STENCIL_DESC rd;
    rd = DepthDisabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &depthDisabled));
    rd = DepthEnabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &depthEnabled));
    rd = ReverseDepthEnabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &revDepthEnabled));
    rd = DepthWriteEnabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &depthWriteEnabled));
    rd = ReverseDepthWriteEnabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &revDepthWriteEnabled));
    rd = DepthStencilWriteEnabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &depthStencilWriteEnabled));
    rd = StencilEnabledDesc(); DXCall(device->CreateDepthStencilState(&rd, &stencilEnabled));
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::DepthDisabledDesc()
{
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

    return dsDesc;
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::DepthEnabledDesc()
{
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

    return dsDesc;
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::ReverseDepthEnabledDesc()
{
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = true;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ZERO;
    dsDesc.DepthFunc = D3D11_COMPARISON_GREATER_EQUAL;
    dsDesc.StencilEnable = false;
    dsDesc.StencilReadMask = D3D11_DEFAULT_STENCIL_READ_MASK;
    dsDesc.StencilWriteMask = D3D11_DEFAULT_STENCIL_WRITE_MASK;
    dsDesc.FrontFace.StencilDepthFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilPassOp = D3D11_STENCIL_OP_REPLACE;
    dsDesc.FrontFace.StencilFunc = D3D11_COMPARISON_ALWAYS;
    dsDesc.BackFace = dsDesc.FrontFace;

    return dsDesc;
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::DepthWriteEnabledDesc()
{
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = true;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
    dsDesc.DepthFunc = D3D11_COMPARISON_LESS_EQUAL;
    dsDesc.StencilEnable = false;
    dsDesc.StencilReadMask = D3D11_DEFAULT_STENCIL_READ_MASK;
    dsDesc.StencilWriteMask = D3D11_DEFAULT_STENCIL_WRITE_MASK;
    dsDesc.FrontFace.StencilDepthFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilPassOp = D3D11_STENCIL_OP_REPLACE;
    dsDesc.FrontFace.StencilFunc = D3D11_COMPARISON_ALWAYS;
    dsDesc.BackFace = dsDesc.FrontFace;

    return dsDesc;
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::ReverseDepthWriteEnabledDesc()
{
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = true;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
    dsDesc.DepthFunc = D3D11_COMPARISON_GREATER_EQUAL;
    dsDesc.StencilEnable = false;
    dsDesc.StencilReadMask = D3D11_DEFAULT_STENCIL_READ_MASK;
    dsDesc.StencilWriteMask = D3D11_DEFAULT_STENCIL_WRITE_MASK;
    dsDesc.FrontFace.StencilDepthFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilPassOp = D3D11_STENCIL_OP_REPLACE;
    dsDesc.FrontFace.StencilFunc = D3D11_COMPARISON_ALWAYS;
    dsDesc.BackFace = dsDesc.FrontFace;

    return dsDesc;
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::DepthStencilWriteEnabledDesc()
{
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = true;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
    dsDesc.DepthFunc = D3D11_COMPARISON_LESS_EQUAL;
    dsDesc.StencilEnable = true;
    dsDesc.StencilReadMask = D3D11_DEFAULT_STENCIL_READ_MASK;
    dsDesc.StencilWriteMask = D3D11_DEFAULT_STENCIL_WRITE_MASK;
    dsDesc.FrontFace.StencilDepthFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilPassOp = D3D11_STENCIL_OP_REPLACE;
    dsDesc.FrontFace.StencilFunc = D3D11_COMPARISON_ALWAYS;
    dsDesc.BackFace = dsDesc.FrontFace;

    return dsDesc;
}

D3D11_DEPTH_STENCIL_DESC DepthStencilStates::StencilEnabledDesc()
{
    D3D11_DEPTH_STENCIL_DESC dsDesc;
    dsDesc.DepthEnable = true;
    dsDesc.DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL;
    dsDesc.DepthFunc = D3D11_COMPARISON_LESS_EQUAL;
    dsDesc.StencilEnable = true;
    dsDesc.StencilReadMask = D3D11_DEFAULT_STENCIL_READ_MASK;
    dsDesc.StencilWriteMask = 0;
    dsDesc.FrontFace.StencilDepthFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFailOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilPassOp = D3D11_STENCIL_OP_KEEP;
    dsDesc.FrontFace.StencilFunc = D3D11_COMPARISON_EQUAL;
    dsDesc.BackFace = dsDesc.FrontFace;

    return dsDesc;
}

void SamplerStates::Initialize(ID3D11Device* device)
{
    D3D11_SAMPLER_DESC rd;
    rd = LinearDesc(); DXCall(device->CreateSamplerState(&rd, &linear));
    rd = LinearClampDesc(); DXCall(device->CreateSamplerState(&rd, &linearClamp));
    rd = LinearBorderDesc(); DXCall(device->CreateSamplerState(&rd, &linearBorder));
    rd = PointDesc(); DXCall(device->CreateSamplerState(&rd, &point));
    rd = AnisotropicDesc(); DXCall(device->CreateSamplerState(&rd, &anisotropic));
    rd = ShadowMapDesc(); DXCall(device->CreateSamplerState(&rd, &shadowMap));
    rd = ShadowMapPCFDesc(); DXCall(device->CreateSamplerState(&rd, &shadowMapPCF));
    rd = ReversedShadowMapDesc(); DXCall(device->CreateSamplerState(&rd, &reversedShadowMap));
    rd = ReversedShadowMapPCFDesc(); DXCall(device->CreateSamplerState(&rd, &reversedShadowMapPCF));
}

D3D11_SAMPLER_DESC SamplerStates::LinearDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::LinearClampDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::LinearBorderDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_LINEAR;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_BORDER;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_BORDER;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_BORDER;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::PointDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_MIN_MAG_MIP_POINT;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::AnisotropicDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_ANISOTROPIC;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_WRAP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 16;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_ALWAYS;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::ShadowMapDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_COMPARISON_MIN_MAG_MIP_POINT;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_LESS_EQUAL;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::ShadowMapPCFDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_COMPARISON_MIN_MAG_MIP_LINEAR;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_LESS_EQUAL;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::ReversedShadowMapDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_COMPARISON_MIN_MAG_MIP_POINT;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_GREATER_EQUAL;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

D3D11_SAMPLER_DESC SamplerStates::ReversedShadowMapPCFDesc()
{
    D3D11_SAMPLER_DESC sampDesc;

    sampDesc.Filter = D3D11_FILTER_COMPARISON_MIN_MAG_MIP_LINEAR;
    sampDesc.AddressU = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressV = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.AddressW = D3D11_TEXTURE_ADDRESS_CLAMP;
    sampDesc.MipLODBias = 0.0f;
    sampDesc.MaxAnisotropy = 1;
    sampDesc.ComparisonFunc = D3D11_COMPARISON_GREATER_EQUAL;
    sampDesc.BorderColor[0] = sampDesc.BorderColor[1] = sampDesc.BorderColor[2] = sampDesc.BorderColor[3] = 0;
    sampDesc.MinLOD = 0;
    sampDesc.MaxLOD = D3D11_FLOAT32_MAX;

    return sampDesc;
}

}