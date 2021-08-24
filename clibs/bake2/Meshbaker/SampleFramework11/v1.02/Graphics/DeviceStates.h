//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"

#include "..\\InterfacePointers.h"

namespace SampleFramework11
{

class BlendStates
{

protected:

    ID3D11BlendStatePtr blendDisabled;
    ID3D11BlendStatePtr additiveBlend;
    ID3D11BlendStatePtr alphaBlend;
    ID3D11BlendStatePtr pmAlphaBlend;
    ID3D11BlendStatePtr noColor;
    ID3D11BlendStatePtr alphaToCoverage;
    ID3D11BlendStatePtr opacityBlend;

public:

    void Initialize(ID3D11Device* device);

    ID3D11BlendState* BlendDisabled () { return blendDisabled; };
    ID3D11BlendState* AdditiveBlend () { return additiveBlend; };
    ID3D11BlendState* AlphaBlend () { return alphaBlend; };
    ID3D11BlendState* PreMultipliedAlphaBlend () { return pmAlphaBlend; };
    ID3D11BlendState* ColorWriteDisabled () { return noColor; };
    ID3D11BlendState* AlphaToCoverage () { return alphaToCoverage; };
    ID3D11BlendState* OpacityBlend() { return opacityBlend; };

    static D3D11_BLEND_DESC BlendDisabledDesc();
    static D3D11_BLEND_DESC AdditiveBlendDesc();
    static D3D11_BLEND_DESC AlphaBlendDesc();
    static D3D11_BLEND_DESC PreMultipliedAlphaBlendDesc();
    static D3D11_BLEND_DESC ColorWriteDisabledDesc();
    static D3D11_BLEND_DESC AlphaToCoverageDesc();
    static D3D11_BLEND_DESC OpacityBlendDesc();
};


class RasterizerStates
{

protected:

    ID3D11RasterizerStatePtr noCull;
    ID3D11RasterizerStatePtr cullBackFaces;
    ID3D11RasterizerStatePtr cullBackFacesScissor;
    ID3D11RasterizerStatePtr cullBackFacesNoZClip;
    ID3D11RasterizerStatePtr cullFrontFaces;
    ID3D11RasterizerStatePtr cullFrontFacesScissor;
    ID3D11RasterizerStatePtr noCullNoMS;
    ID3D11RasterizerStatePtr noCullScissor;
    ID3D11RasterizerStatePtr wireframe;

public:

    void Initialize(ID3D11Device* device);

    ID3D11RasterizerState* NoCull() { return noCull; };
    ID3D11RasterizerState* BackFaceCull() { return cullBackFaces; };
    ID3D11RasterizerState* BackFaceCullScissor() { return cullBackFacesScissor; };
    ID3D11RasterizerState* BackFaceCullNoZClip() { return cullBackFacesNoZClip; };
    ID3D11RasterizerState* FrontFaceCull() { return cullFrontFaces; };
    ID3D11RasterizerState* FrontFaceCullScissor() { return cullFrontFacesScissor; };
    ID3D11RasterizerState* NoCullNoMS() { return noCullNoMS; };
    ID3D11RasterizerState* NoCullScissor() { return noCullScissor; };
    ID3D11RasterizerState* Wireframe() { return wireframe; };

    static D3D11_RASTERIZER_DESC NoCullDesc();
    static D3D11_RASTERIZER_DESC FrontFaceCullDesc();
    static D3D11_RASTERIZER_DESC FrontFaceCullScissorDesc();
    static D3D11_RASTERIZER_DESC BackFaceCullDesc();
    static D3D11_RASTERIZER_DESC BackFaceCullScissorDesc();
    static D3D11_RASTERIZER_DESC BackFaceCullNoZClipDesc();
    static D3D11_RASTERIZER_DESC NoCullNoMSDesc();
    static D3D11_RASTERIZER_DESC NoCullScissorDesc();
    static D3D11_RASTERIZER_DESC WireframeDesc();
};


class DepthStencilStates
{
    ID3D11DepthStencilStatePtr depthDisabled;
    ID3D11DepthStencilStatePtr depthEnabled;
    ID3D11DepthStencilStatePtr revDepthEnabled;
    ID3D11DepthStencilStatePtr depthWriteEnabled;
    ID3D11DepthStencilStatePtr revDepthWriteEnabled;
    ID3D11DepthStencilStatePtr depthStencilWriteEnabled;
    ID3D11DepthStencilStatePtr stencilEnabled;

public:

    void Initialize(ID3D11Device* device);

    ID3D11DepthStencilState* DepthDisabled() { return depthDisabled; };
    ID3D11DepthStencilState* DepthEnabled() { return depthEnabled; };
    ID3D11DepthStencilState* ReverseDepthEnabled() { return revDepthEnabled; };
    ID3D11DepthStencilState* DepthWriteEnabled() { return depthWriteEnabled; };
    ID3D11DepthStencilState* ReverseDepthWriteEnabled() { return revDepthWriteEnabled; };
    ID3D11DepthStencilState* DepthStencilWriteEnabled() { return depthStencilWriteEnabled; };
    ID3D11DepthStencilState* StencilTestEnabled() { return depthStencilWriteEnabled; };

    static D3D11_DEPTH_STENCIL_DESC DepthDisabledDesc();
    static D3D11_DEPTH_STENCIL_DESC DepthEnabledDesc();
    static D3D11_DEPTH_STENCIL_DESC ReverseDepthEnabledDesc();
    static D3D11_DEPTH_STENCIL_DESC DepthWriteEnabledDesc();
    static D3D11_DEPTH_STENCIL_DESC ReverseDepthWriteEnabledDesc();
    static D3D11_DEPTH_STENCIL_DESC DepthStencilWriteEnabledDesc();
    static D3D11_DEPTH_STENCIL_DESC StencilEnabledDesc();
};


class SamplerStates
{

    ID3D11SamplerStatePtr linear;
    ID3D11SamplerStatePtr linearClamp;
    ID3D11SamplerStatePtr linearBorder;
    ID3D11SamplerStatePtr point;
    ID3D11SamplerStatePtr anisotropic;
    ID3D11SamplerStatePtr shadowMap;
    ID3D11SamplerStatePtr shadowMapPCF;
    ID3D11SamplerStatePtr reversedShadowMap;
    ID3D11SamplerStatePtr reversedShadowMapPCF;
public:

    void Initialize(ID3D11Device* device);

    ID3D11SamplerState* Linear() { return linear; };
    ID3D11SamplerState* LinearClamp() { return linearClamp; };
    ID3D11SamplerState* LinearBorder() { return linearBorder; };
    ID3D11SamplerState* Point() { return point; };
    ID3D11SamplerState* Anisotropic() { return anisotropic; };
    ID3D11SamplerState* ShadowMap() { return shadowMap; };
    ID3D11SamplerState* ShadowMapPCF() { return shadowMapPCF; };
    ID3D11SamplerState* ReversedShadowMap() { return reversedShadowMap; };
    ID3D11SamplerState* ReversedShadowMapPCF() { return reversedShadowMapPCF; };

    static D3D11_SAMPLER_DESC LinearDesc();
    static D3D11_SAMPLER_DESC LinearClampDesc();
    static D3D11_SAMPLER_DESC LinearBorderDesc();
    static D3D11_SAMPLER_DESC PointDesc();
    static D3D11_SAMPLER_DESC AnisotropicDesc();
    static D3D11_SAMPLER_DESC ShadowMapDesc();
    static D3D11_SAMPLER_DESC ShadowMapPCFDesc();
    static D3D11_SAMPLER_DESC ReversedShadowMapDesc();
    static D3D11_SAMPLER_DESC ReversedShadowMapPCFDesc();
};

}
