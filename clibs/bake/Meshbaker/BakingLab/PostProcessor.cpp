//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include <PCH.h>

#include <Graphics/ShaderCompilation.h>
#include <Graphics/Profiler.h>
#include <Graphics/Camera.h>
#include <Graphics/Textures.h>

#include "PostProcessor.h"
#include "SharedConstants.h"

// Constants
static const uint32 TGSize = 16;
static const uint32 LumMapSize = 1024;

void PostProcessor::Initialize(ID3D11Device* device)
{
    PostProcessorBase::Initialize(device);

    constantBuffer.Initialize(device);

    // Load the shaders
    toneMap = CompilePSFromFile(device, L"ToneMapping.hlsl", "ToneMap");
    scale = CompilePSFromFile(device, L"PostProcessing.hlsl", "Scale");
    blurH = CompilePSFromFile(device, L"PostProcessing.hlsl", "BlurH");
    blurV = CompilePSFromFile(device, L"PostProcessing.hlsl", "BlurV");
    bloom = CompilePSFromFile(device, L"PostProcessing.hlsl", "Bloom");

    CompileOptions opts;
    opts.Add("MSAA_", 0);
    dofDownscale[0] = CompilePSFromFile(device, L"PostProcessing.hlsl", "DOFDownscale", "ps_5_0", opts);

    opts.Reset();
    opts.Add("MSAA_", 1);
    dofDownscale[1] = CompilePSFromFile(device, L"PostProcessing.hlsl", "DOFDownscale", "ps_5_0", opts);

    dilateNearMask = CompilePSFromFile(device, L"PostProcessing.hlsl", "DilateNearMask");
    nearMaskBlurH = CompilePSFromFile(device, L"PostProcessing.hlsl", "NearMaskBlurH");
    nearMaskBlurV = CompilePSFromFile(device, L"PostProcessing.hlsl", "NearMaskBlurV");

    opts.Reset();
    opts.Add("MSAA_", 0);
    dofComposite[0] = CompilePSFromFile(device, L"PostProcessing.hlsl", "DOFComposite", "ps_5_0", opts);

    opts.Reset();
    opts.Add("MSAA_", 1);
    dofComposite[1] = CompilePSFromFile(device, L"PostProcessing.hlsl", "DOFComposite", "ps_5_0", opts);

    floodFillDOF = CompilePSFromFile(device, L"PostProcessing.hlsl", "FloodFillDOF");
    kernelGatherDOF = CompilePSFromFile(device, L"PostProcessing.hlsl", "KernelGatherDOF");

    opts.Reset();
    opts.Add("TGSize_", 16);
    computeNearMask16 = CompileCSFromFile(device, L"ComputeNearMask.hlsl", "ComputeNearMask", "cs_5_0", opts);

    reduceLuminanceInitial = CompileCSFromFile(device, L"LuminanceReduction.hlsl",
                                                    "LuminanceReductionInitialCS", "cs_5_0");
    reduceLuminance = CompileCSFromFile(device, L"LuminanceReduction.hlsl", "LuminanceReductionCS");

    opts.Reset();
    opts.Add("FinalPass_", 1);
    reduceLuminanceFinal = CompileCSFromFile(device, L"LuminanceReduction.hlsl", "LuminanceReductionCS",
                                             "cs_5_0", opts);
}

void PostProcessor::AfterReset(uint32 width, uint32 height)
{
    PostProcessorBase::AfterReset(width, height);

    reductionTargets.clear();

    uint32 w = width;
    uint32 h = height;

    while(w > 1 || h > 1)
    {
        w = DispatchSize(ReductionTGSize, w);
        h = DispatchSize(ReductionTGSize, h);

        RenderTarget2D rt;
        rt.Initialize(device, w, h, DXGI_FORMAT_R32_FLOAT, 1, 1, 0, false, true);
        reductionTargets.push_back(rt);
    }

    adaptedLuminance = reductionTargets[reductionTargets.size() - 1].SRView;

    constantBuffer.Data.EnableAdaptation = false;
}

void PostProcessor::Render(ID3D11DeviceContext* deviceContext, ID3D11ShaderResourceView* input,
                           ID3D11ShaderResourceView* depthBuffer, const Camera& camera,
                           ID3D11RenderTargetView* output, float deltaSeconds)
{
    PostProcessorBase::Render(deviceContext, input, output);

    constantBuffer.Data.TimeDelta = deltaSeconds;
    constantBuffer.Data.Projection = camera.ProjectionMatrix();
    constantBuffer.Data.DisplayWidth = float(inputWidth);
    constantBuffer.Data.DisplayHeight = float(inputHeight);

    constantBuffer.ApplyChanges(deviceContext);
    constantBuffer.SetPS(deviceContext, 1);

    bool enableDOF = AppSettings::ShowGroundTruth == false && AppSettings::EnableDOF;
    TempRenderTarget* dofTarget = nullptr;
    TempRenderTarget* nearMask = nullptr;
    ID3D11ShaderResourceView* dofResult = input;
    ID3D11ShaderResourceView* nearMaskSRV = nullptr;
    if(enableDOF)
    {
        dofTarget = DOF(input, depthBuffer, nearMask);
        dofResult = dofTarget->SRView;
        nearMaskSRV = nearMask->SRView;
    }

    if(AppSettings::ExposureMode == ExposureModes::Automatic)
        CalcAvgLuminance(dofResult);

    TempRenderTarget* bloom = Bloom(dofResult);

    // Apply tone mapping
    ToneMap(dofResult, bloom->SRView, output);

    bloom->InUse = false;
    if(dofTarget != nullptr)
        dofTarget->InUse = false;
    if(nearMask != nullptr)
        nearMask->InUse = false;
    constantBuffer.Data.EnableAdaptation = true;

    // Check for leaked temp render targets
    for(uint64 i = 0; i < tempRenderTargets.size(); ++i)
        Assert_(tempRenderTargets[i]->InUse == false);
}

void PostProcessor::CalcAvgLuminance(ID3D11ShaderResourceView* input)
{
    // Calculate the geometric mean of luminance through reduction
    PIXEvent pixEvent(L"Average Luminance Calculation");

    constantBuffer.SetCS(context, 0);

    ID3D11UnorderedAccessView* uavs[1] = { reductionTargets[0].UAView };
    context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

    ID3D11ShaderResourceView* srvs[1] = { input };
    context->CSSetShaderResources(0, 1, srvs);

    context->CSSetShader(reduceLuminanceInitial, NULL, 0);

    uint32 dispatchX = reductionTargets[0].Width;
    uint32 dispatchY = reductionTargets[0].Height;
    context->Dispatch(dispatchX, dispatchY, 1);

    uavs[0] = NULL;
    context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

    srvs[0] = NULL;
    context->CSSetShaderResources(0, 1, srvs);

    for(uint32 i = 1; i < reductionTargets.size(); ++i)
    {
        if(i == reductionTargets.size() - 1)
            context->CSSetShader(reduceLuminanceFinal, NULL, 0);
        else
            context->CSSetShader(reduceLuminance, NULL, 0);

        uavs[0] = reductionTargets[i].UAView;
        context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

        srvs[0] = reductionTargets[i - 1].SRView;
        context->CSSetShaderResources(0, 1, srvs);

        dispatchX = reductionTargets[i].Width;
        dispatchY = reductionTargets[i].Height;
        context->Dispatch(dispatchX, dispatchY, 1);

        uavs[0] = NULL;
        context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

        srvs[0] = NULL;
        context->CSSetShaderResources(0, 1, srvs);
    }
}

TempRenderTarget* PostProcessor::Bloom(ID3D11ShaderResourceView* input)
{
    PIXEvent pixEvent(L"Bloom");

    TempRenderTarget* downscale1 = GetTempRenderTarget(inputWidth / 2, inputHeight / 2, DXGI_FORMAT_R16G16B16A16_FLOAT);
    inputs.push_back(input);
    inputs.push_back(adaptedLuminance);
    outputs.push_back(downscale1->RTView);
    PostProcess(bloom, L"Bloom Initial Pass");

    // Blur it
    for(uint64 i = 0; i < 2; ++i)
    {
        TempRenderTarget* blurTemp = GetTempRenderTarget(inputWidth / 2, inputHeight / 2, DXGI_FORMAT_R16G16B16A16_FLOAT);
        PostProcess(downscale1->SRView, blurTemp->RTView, blurH, L"Horizontal Bloom Blur");

        PostProcess(blurTemp->SRView, downscale1->RTView, blurV, L"Vertical Bloom Blur");
        blurTemp->InUse = false;
    }

    return downscale1;
}

void PostProcessor::ToneMap(ID3D11ShaderResourceView* input,
                            ID3D11ShaderResourceView* bloom,
                            ID3D11RenderTargetView* output)
{
    // Use an intermediate render target so that we can render do sRGB conversion ourselves in the shader
    TempRenderTarget* tmOutput = GetTempRenderTarget(inputWidth, inputHeight, DXGI_FORMAT_R8G8B8A8_UNORM);

    inputs.push_back(input);
    inputs.push_back(adaptedLuminance);
    inputs.push_back(bloom);
    outputs.push_back(tmOutput->RTView);

    PostProcess(toneMap, L"Tone Mapping");

    ID3D11ResourcePtr outputResource;
    output->GetResource(&outputResource);

    context->CopyResource(outputResource, tmOutput->Texture);

    tmOutput->InUse = false;
}

TempRenderTarget* PostProcessor::DOF(ID3D11ShaderResourceView* input, ID3D11ShaderResourceView* depthBuffer,
                                     TempRenderTarget*& nearMask)
{
    uint32 dofResX = inputWidth / 2;
    uint32 dofResY = inputHeight / 2;

    TempRenderTarget* nearTarget = GetTempRenderTarget(dofResX, dofResY, DXGI_FORMAT_R16G16B16A16_FLOAT);
    TempRenderTarget* farTarget = GetTempRenderTarget(dofResX, dofResY, DXGI_FORMAT_R16G16B16A16_FLOAT);

    inputs.push_back(input);
    inputs.push_back(depthBuffer);
    outputs.push_back(nearTarget->RTView);
    outputs.push_back(farTarget->RTView);

    if(AppSettings::MSAAMode == MSAAModes::MSAANone)
        PostProcess(dofDownscale[0], L"DOF Downscale");
    else
        PostProcess(dofDownscale[1], L"DOF Downscale");

    const uint32 tileSize = 32;
    const uint32 numTilesX = (inputWidth + (tileSize - 1)) / tileSize;
    const uint32 numTilesY = (inputHeight + (tileSize - 1)) / tileSize;
    TempRenderTarget* nearMaskInitial = GetTempRenderTarget(numTilesX, numTilesY, DXGI_FORMAT_R16_UNORM, 1, 0, 1, false, true);

    ID3D11RenderTargetView* rtvs[2] = { nullptr, nullptr };
    context->OMSetRenderTargets(2, rtvs, nullptr);
    SetCSInputs(context, nearTarget->SRView);
    SetCSOutputs(context, nearMaskInitial->UAView);
    SetCSShader(context, computeNearMask16);

    context->Dispatch(numTilesX, numTilesY, 1);

    ClearCSInputs(context);
    ClearCSOutputs(context);

    nearMask = GetTempRenderTarget(numTilesX, numTilesY, DXGI_FORMAT_R16_UNORM, 1, 0, 1, false, false);
    PostProcess(nearMaskInitial->SRView, nearMask->RTView, dilateNearMask, L"Dilate Near Mask");

    nearMaskInitial->InUse = false;

    const uint32 numIterations = 1;
    for(uint32 i = 0; i < numIterations; ++i)
    {
        TempRenderTarget* nearMaskTemp = GetTempRenderTarget(numTilesX, numTilesY, nearMask->Format);
        PostProcess(nearMask->SRView, nearMaskTemp->RTView, nearMaskBlurH, L"Near Mask Blur H");

        PostProcess(nearMaskTemp->SRView, nearMask->RTView, nearMaskBlurV, L"Near Mask Blur V");
        nearMaskTemp->InUse = false;
    }

    TempRenderTarget* nearResult = GetTempRenderTarget(dofResX, dofResY, DXGI_FORMAT_R16G16B16A16_FLOAT);
    TempRenderTarget* farResult = GetTempRenderTarget(dofResX, dofResY, DXGI_FORMAT_R16G16B16A16_FLOAT);

    inputs.push_back(nearTarget->SRView);
    inputs.push_back(farTarget->SRView);
    inputs.push_back(nearMask->SRView);
    outputs.push_back(nearResult->RTView);
    outputs.push_back(farResult->RTView);

    PostProcess(kernelGatherDOF, L"Kernel Gather DOF");

    nearTarget->InUse = false;
    farTarget->InUse = false;

    TempRenderTarget* floodFilledNear = GetTempRenderTarget(dofResX, dofResY, DXGI_FORMAT_R16G16B16A16_FLOAT);
    TempRenderTarget* floodFilledFar = GetTempRenderTarget(dofResX, dofResY, DXGI_FORMAT_R16G16B16A16_FLOAT);

    inputs.push_back(nearResult->SRView);
    inputs.push_back(farResult->SRView);
    outputs.push_back(floodFilledNear->RTView);
    outputs.push_back(floodFilledFar->RTView);

    PostProcess(floodFillDOF, L"DOF Flood-Fill");

    nearResult->InUse = false;
    farResult->InUse = false;

    TempRenderTarget* dofResult = GetTempRenderTarget(inputWidth, inputHeight, DXGI_FORMAT_R16G16B16A16_FLOAT);
    inputs.push_back(floodFilledNear->SRView);
    inputs.push_back(floodFilledFar->SRView);
    inputs.push_back(input);
    inputs.push_back(nearMask->SRView);
    inputs.push_back(depthBuffer);
    outputs.push_back(dofResult->RTView);

    if(AppSettings::MSAAMode == MSAAModes::MSAANone)
        PostProcess(dofComposite[0], L"DOF Composite");
    else
        PostProcess(dofComposite[1], L"DOF Composite");

    floodFilledNear->InUse = false;
    floodFilledFar->InUse = false;

    nearMask->InUse = false;

    return dofResult;
}