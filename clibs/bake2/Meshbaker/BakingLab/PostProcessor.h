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

#include <PCH.h>
#include <Graphics/GraphicsTypes.h>
#include <Graphics/PostProcessorBase.h>
#include <Graphics/DeviceStates.h>

#include "AppSettings.h"

using namespace SampleFramework11;

namespace SampleFramework11
{
    class Camera;
}

class PostProcessor : public PostProcessorBase
{

public:

    void Initialize(ID3D11Device* device);

    void Render(ID3D11DeviceContext* deviceContext, ID3D11ShaderResourceView* input,
                ID3D11ShaderResourceView* depthBuffer, const Camera& camera,
                ID3D11RenderTargetView* output, float deltaSeconds);
    void AfterReset(UINT width, UINT height);

    ID3D11ShaderResourceView* AdaptedLuminance() { return adaptedLuminance; }

protected:

    void CalcAvgLuminance(ID3D11ShaderResourceView* input);
    TempRenderTarget* Bloom(ID3D11ShaderResourceView* input);
    void ToneMap(ID3D11ShaderResourceView* input,
                 ID3D11ShaderResourceView* bloom,
                 ID3D11RenderTargetView* output);

     TempRenderTarget* DOF(ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* depthBuffer,
                           TempRenderTarget*& nearMask);

    ComputeShaderPtr reduceLuminanceInitial;
    ComputeShaderPtr reduceLuminance;
    ComputeShaderPtr reduceLuminanceFinal;
    PixelShaderPtr toneMap;
    PixelShaderPtr scale;
    PixelShaderPtr bloom;
    PixelShaderPtr blurH;
    PixelShaderPtr blurV;

    PixelShaderPtr dofDownscale[2];
    PixelShaderPtr dilateNearMask;
    PixelShaderPtr nearMaskBlurH;
    PixelShaderPtr nearMaskBlurV;
    PixelShaderPtr dofComposite[2];
    PixelShaderPtr kernelGatherDOF;
    PixelShaderPtr floodFillDOF;
    ComputeShaderPtr computeNearMask16;

    std::vector<RenderTarget2D> reductionTargets;
    ID3D11ShaderResourceView* adaptedLuminance;

    struct Constants
    {
        float TimeDelta;
        uint32 EnableAdaptation;

        float DisplayWidth;
        float DisplayHeight;

        Float4x4 Projection;
    };

    ConstantBuffer<Constants> constantBuffer;
};