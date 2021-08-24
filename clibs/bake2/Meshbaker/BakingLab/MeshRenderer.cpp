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

#include "MeshRenderer.h"

#include <Exceptions.h>
#include <Utility.h>
#include <Graphics/ShaderCompilation.h>
#include <App.h>

#include "AppSettings.h"
#include "SharedConstants.h"
#include "MeshBaker.h"

// Constants
static const float ShadowNearClip = 1.0f;
static const float FilterSize = 7.0f;
static const uint32 SampleRadius = 3;
static const float OffsetScale = 0.0f;
static const float LightBleedingReduction = 0.10f;
static const float PositiveExponent = 40.0f;
static const float NegativeExponent = 8.0f;
static const uint32 ShadowMapSize = 1024;
static const uint32 ShadowMSAASamples = 4;
static const uint32 ShadowAnisotropy = 16;
static const bool EnableShadowMips = true;

static void GenerateHemisphere(uint64 NumUSlices, uint64 NumVSlices, ID3D11Device* device,
                               ID3D11BufferPtr& vtxBuffer, ID3D11BufferPtr& idxBuffer, uint64& numIndices)
{
    Assert_(NumUSlices >= 3);
    Assert_(NumVSlices >= 2);

    std::vector<Float3> hemisphereVerts;

    // Add the vert at the top
    hemisphereVerts.push_back(Float3(0.0f, 0.0f, 1.0f));

    // Add the rings
    for(uint64 v = 0; v < NumVSlices; ++v)
    {
        for(uint64 u = 0; u < NumUSlices; ++u)
        {
            const float theta = ((v + 1.0f) / NumVSlices) * Pi_2;
            const float phi = (float(u) / NumUSlices) * Pi2;

            Float3 pos;
            pos.x = std::sin(theta) * std::cos(phi);
            pos.y = std::sin(theta) * std::sin(phi);
            pos.z = std::cos(theta);

            hemisphereVerts.push_back(pos);
        }
    }

    Assert_(hemisphereVerts.size() <= UINT32_MAX);

    // Add the top ring of triangles
    std::vector<uint32> hemisphereIndices;
    for(uint32 u = 0; u < NumUSlices; ++u)
    {
        hemisphereIndices.push_back(0);
        hemisphereIndices.push_back(u + 1);

        if(u < NumUSlices - 1)
            hemisphereIndices.push_back(u + 2);
        else
            hemisphereIndices.push_back(1);
    }

    // Add the rest of the rings
    uint32 prevRowStart = 1;
    uint32 currRowStart = uint32(NumUSlices + 1);
    for(uint32 v = 1; v < NumVSlices; ++v)
    {
        for(uint32 u = 0; u < NumUSlices; ++u)
        {
            uint32 nextBottom = currRowStart + u + 1;
            uint32 nextTop = prevRowStart + u + 1;
            if(u == NumUSlices - 1)
            {
                nextBottom = currRowStart;
                nextTop = prevRowStart;
            }

            hemisphereIndices.push_back(prevRowStart + u);
            hemisphereIndices.push_back(currRowStart + u);
            hemisphereIndices.push_back(nextBottom);
            hemisphereIndices.push_back(nextBottom);
            hemisphereIndices.push_back(nextTop);
            hemisphereIndices.push_back(prevRowStart + u);
        }

        prevRowStart = currRowStart;
        currRowStart += uint32(NumUSlices);
    }

    numIndices = hemisphereIndices.size();

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.ByteWidth = sizeof(Float3) * uint32(hemisphereVerts.size());
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = hemisphereVerts.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vtxBuffer));

    bufferDesc.ByteWidth = sizeof(uint32) * uint32(hemisphereIndices.size());
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    initData.pSysMem = hemisphereIndices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &idxBuffer));
}

static void GenerateSphere(uint64 NumUSlices, uint64 NumVSlices, ID3D11Device* device,
                           ID3D11BufferPtr& vtxBuffer, ID3D11BufferPtr& idxBuffer, uint64& numIndices)
{
    Assert_(NumUSlices >= 3);
    Assert_(NumVSlices >= 3);

    std::vector<Float3> sphereVerts;

    // Add the vert at the top
    sphereVerts.push_back(Float3(0.0f, 0.0f, 1.0f));

    // Add the rings
    for(uint64 v = 0; v < NumVSlices - 1; ++v)
    {
        for(uint64 u = 0; u < NumUSlices; ++u)
        {
            const float theta = ((v + 1.0f) / NumVSlices) * Pi;
            const float phi = (float(u) / NumUSlices) * Pi2;

            Float3 pos;
            pos.x = std::sin(theta) * std::cos(phi);
            pos.y = std::sin(theta) * std::sin(phi);
            pos.z = std::cos(theta);

            sphereVerts.push_back(pos);
        }
    }

    // Add the vert at the bottom
    const uint32 lastVertIdx = uint32(sphereVerts.size());
    sphereVerts.push_back(Float3(0.0f, 0.0f, -1.0f));

    Assert_(sphereVerts.size() <= UINT32_MAX);

    // Add the top ring of triangles
    std::vector<uint32> sphereIndices;
    for(uint32 u = 0; u < NumUSlices; ++u)
    {
        sphereIndices.push_back(0);
        sphereIndices.push_back(u + 1);

        if(u < NumUSlices - 1)
            sphereIndices.push_back(u + 2);
        else
            sphereIndices.push_back(1);
    }

    // Add the rest of the rings
    uint32 prevRowStart = 1;
    uint32 currRowStart = uint32(NumUSlices + 1);
    for(uint32 v = 1; v < NumVSlices - 1; ++v)
    {
        for(uint32 u = 0; u < NumUSlices; ++u)
        {
            uint32 nextBottom = currRowStart + u + 1;
            uint32 nextTop = prevRowStart + u + 1;
            if(u == NumUSlices - 1)
            {
                nextBottom = currRowStart;
                nextTop = prevRowStart;
            }

            sphereIndices.push_back(prevRowStart + u);
            sphereIndices.push_back(currRowStart + u);
            sphereIndices.push_back(nextBottom);
            sphereIndices.push_back(nextBottom);
            sphereIndices.push_back(nextTop);
            sphereIndices.push_back(prevRowStart + u);
        }

        prevRowStart = currRowStart;
        currRowStart += uint32(NumUSlices);
    }

    // Add the last ring at the bottom
    const uint32 lastRingStart = uint32(lastVertIdx - NumUSlices);
    for(uint32 u = 0; u < NumUSlices; ++u)
    {
        sphereIndices.push_back(lastVertIdx);
        sphereIndices.push_back(lastRingStart + u);

        if(u < NumUSlices - 1)
            sphereIndices.push_back(lastRingStart + u + 1);
        else
            sphereIndices.push_back(lastRingStart);
    }

    numIndices = sphereIndices.size();

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.ByteWidth = sizeof(Float3) * uint32(sphereVerts.size());
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = sphereVerts.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vtxBuffer));

    bufferDesc.ByteWidth = sizeof(uint32) * uint32(sphereIndices.size());
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    initData.pSysMem = sphereIndices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &idxBuffer));
}

MeshRenderer::MeshRenderer() : currFrame(0), sceneModel(nullptr),
                                numHemisphereIndices(0), numAreaLightIndices(0)
{
}

void MeshRenderer::LoadShaders()
{
    // Load the mesh shaders
    meshDepthVS = CompileVSFromFile(device, L"DepthOnly.hlsl", "VS", "vs_5_0");
    meshVS = CompileVSFromFile(device, L"Mesh.hlsl", "VS", "vs_5_0");
    meshPS = CompilePSFromFile(device, L"Mesh.hlsl", "PS", "ps_5_0");

    areaLightVS = CompileVSFromFile(device, L"AreaLight.hlsl", "VS", "vs_5_0");
    areaLightPS = CompilePSFromFile(device, L"AreaLight.hlsl", "PS", "ps_5_0");

    visualizerVS = CompileVSFromFile(device, L"BakeDataVisualizer.hlsl", "VS", "vs_5_0");
    visualizerPS = CompilePSFromFile(device, L"BakeDataVisualizer.hlsl", "PS", "ps_5_0");

    fullScreenVS = CompileVSFromFile(device, L"EVSMConvert.hlsl", "FullScreenVS");

    CompileOptions opts;
    opts.Add("MSAASamples_", ShadowMSAASamples);
    evsmConvertPS = CompilePSFromFile(device, L"EVSMConvert.hlsl", "ConvertToEVSM", "ps_5_0", opts);

    opts.Reset();
    opts.Add("Horizontal_", 1);
    opts.Add("Vertical_", 0);
    opts.Add("SampleRadius_", SampleRadius);
    evsmBlurH = CompilePSFromFile(device, L"EVSMConvert.hlsl", "BlurEVSM", "ps_5_0", opts);

    opts.Reset();
    opts.Add("Horizontal_", 0);
    opts.Add("Vertical_", 1);
    opts.Add("SampleRadius_", SampleRadius);
    evsmBlurV = CompilePSFromFile(device, L"EVSMConvert.hlsl", "BlurEVSM", "ps_5_0", opts);

    opts.Reset();
    opts.Add("MSAA_", 0);
    depthReductionInitialCS[0] = CompileCSFromFile(device, L"DepthReduction.hlsl", "DepthReductionInitialCS", "cs_5_0", opts);

    opts.Reset();
    opts.Add("MSAA_", 1);
    depthReductionInitialCS[1] = CompileCSFromFile(device, L"DepthReduction.hlsl", "DepthReductionInitialCS", "cs_5_0", opts);

    depthReductionCS = CompileCSFromFile(device, L"DepthReduction.hlsl", "DepthReductionCS");
}

void MeshRenderer::CreateShadowMaps()
{
    // Create the shadow map as a texture atlas
    sunShadowDepthMap.Initialize(device, ShadowMapSize, ShadowMapSize, DXGI_FORMAT_D24_UNORM_S8_UINT, true,
                                 ShadowMSAASamples, 0, 1);

    DXGI_FORMAT smFmt = DXGI_FORMAT_R32G32B32A32_FLOAT;
    uint32 numMips = EnableShadowMips ? 0 : 1;
    sunVSM.Initialize(device, ShadowMapSize, ShadowMapSize, smFmt, numMips, 1, 0,
                                 EnableShadowMips, false, NumCascades, false);

    tempVSM.Initialize(device, ShadowMapSize, ShadowMapSize, smFmt, 1, 1, 0, false, false, 1, false);

    areaLightShadowMap.Initialize(device, ShadowMapSize, ShadowMapSize, DXGI_FORMAT_D32_FLOAT, true, 1, 0, 6, true);
}

// Loads resources
void MeshRenderer::Initialize(ID3D11Device* device, ID3D11DeviceContext* context, const Model* model)
{
    this->device = device;

    blendStates.Initialize(device);
    rasterizerStates.Initialize(device);
    depthStencilStates.Initialize(device);
    samplerStates.Initialize(device);

    meshVSConstants.Initialize(device);
    meshPSConstants.Initialize(device);
    areaLightConstants.Initialize(device);
    visualizerConstants.Initialize(device);
    evsmConstants.Initialize(device);
    reductionConstants.Initialize(device);

    shSpecularLookupA = LoadTexture(device, L"..\\Content\\Textures\\SHSpecularA.dds");
    shSpecularLookupB = LoadTexture(device, L"..\\Content\\Textures\\SHSpecularB.dds");
    envSpecularLookup = LoadTexture(device, L"..\\Content\\Textures\\EnvSpecularLookup.dds");

    LoadShaders();

    D3D11_RASTERIZER_DESC rsDesc = RasterizerStates::NoCullDesc();
    rsDesc.DepthClipEnable = false;
    DXCall(device->CreateRasterizerState(&rsDesc, &noZClipRSState));

    D3D11_SAMPLER_DESC sampDesc = SamplerStates::AnisotropicDesc();
    sampDesc.MaxAnisotropy = ShadowAnisotropy;
    DXCall(device->CreateSamplerState(&sampDesc, &evsmSampler));

    // Create the staging textures for reading back the reduced depth buffer
    for(uint32 i = 0; i < ReadbackLatency; ++i)
        reductionStagingTextures[i].Initialize(device, 1, 1, DXGI_FORMAT_R16G16_UNORM);

    CreateShadowMaps();

    GenerateHemisphere(16, 4, device, hemisphereVB, hemisphereIB, numHemisphereIndices);

    GenerateSphere(256, 192, device, areaLightVB, areaLightIB, numAreaLightIndices);

    D3D11_INPUT_ELEMENT_DESC elements[1];
    elements[0].AlignedByteOffset = 0;
    elements[0].Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elements[0].InputSlot = 0;
    elements[0].InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    elements[0].InstanceDataStepRate = 0;
    elements[0].SemanticName = "POSITION";
    elements[0].SemanticIndex = 0;

    DXCall(device->CreateInputLayout(elements, 1, visualizerVS->ByteCode->GetBufferPointer(),
                                     visualizerVS->ByteCode->GetBufferSize(), &visualizerInputLayout));

    DXCall(device->CreateInputLayout(elements, 1, areaLightVS->ByteCode->GetBufferPointer(),
                                     areaLightVS->ByteCode->GetBufferSize(), &areaLightInputLayout));

    SetModel(model);
}

void MeshRenderer::SetModel(const Model* model)
{
    Assert_(model != nullptr);
    sceneModel = model;

    meshInputLayouts.clear();
    meshDepthInputLayouts.clear();

    for(uint64 i = 0; i < sceneModel->Meshes().size(); ++i)
    {
        // Generate input layouts for the scene meshes
        const Mesh& mesh = sceneModel->Meshes()[i];
        ID3D11InputLayoutPtr inputLayout;
        DXCall(device->CreateInputLayout(mesh.InputElements(), mesh.NumInputElements(),
               meshVS->ByteCode->GetBufferPointer(), meshVS->ByteCode->GetBufferSize(), &inputLayout));
        meshInputLayouts.push_back(inputLayout);

        DXCall(device->CreateInputLayout(mesh.InputElements(), mesh.NumInputElements(),
               meshDepthVS->ByteCode->GetBufferPointer(), meshDepthVS->ByteCode->GetBufferSize(), &inputLayout));
        meshDepthInputLayouts.push_back(inputLayout);
    }
}

void MeshRenderer::Update(const Camera& camera, Float2 jitterOffset)
{
    prevVP = currVP;
    currVP = camera.ViewProjectionMatrix();
    if(firstFrame)
    {
        prevVP = currVP;
        firstFrame = false;
    }

    meshPSConstants.Data.JitterOffset = jitterOffset;
    areaLightConstants.Data.JitterOffset = jitterOffset;
}

void MeshRenderer::OnResize(uint32 width, uint32 height)
{
    depthReductionTargets.clear();

    uint32 w = width;
    uint32 h = height;

    while(w > 1 || h > 1)
    {
        w = DispatchSize(ReductionTGSize, w);
        h = DispatchSize(ReductionTGSize, h);

        RenderTarget2D rt;
        rt.Initialize(device, w, h, DXGI_FORMAT_R16G16_UNORM, 1, 1, 0, false, true);
        depthReductionTargets.push_back(rt);
    }

    meshPSConstants.Data.RTSize.x = float(width);
    meshPSConstants.Data.RTSize.y = float(height);

    areaLightConstants.Data.RTSize = meshPSConstants.Data.RTSize;
}

void MeshRenderer::ReduceDepth(ID3D11DeviceContext* context, DepthStencilBuffer& depthTarget,
                               const Camera& camera)
{
    PIXEvent event(L"Depth Reduction");

    reductionConstants.Data.Projection = Float4x4::Transpose(camera.ProjectionMatrix());
    reductionConstants.Data.NearClip = camera.NearClip();
    reductionConstants.Data.FarClip = camera.FarClip();
    reductionConstants.Data.TextureSize = Uint2(depthTarget.Width, depthTarget.Height);
    reductionConstants.Data.NumSamples = depthTarget.MultiSamples;
    reductionConstants.ApplyChanges(context);
    reductionConstants.SetCS(context, 0);

    ID3D11RenderTargetView* rtvs[1] = { NULL };
    context->OMSetRenderTargets(1, rtvs, NULL);

    ID3D11UnorderedAccessView* uavs[1] = { depthReductionTargets[0].UAView };
    context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

    ID3D11ShaderResourceView* srvs[1] = { depthTarget.SRView };
    context->CSSetShaderResources(0, 1, srvs);

    const bool msaa = depthTarget.MultiSamples > 1;

    ID3D11ComputeShader* shader = depthReductionInitialCS[msaa ? 1 : 0];
    context->CSSetShader(shader, NULL, 0);

    uint32 dispatchX = depthReductionTargets[0].Width;
    uint32 dispatchY = depthReductionTargets[0].Height;
    context->Dispatch(dispatchX, dispatchY, 1);

    uavs[0] = NULL;
    context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

    srvs[0] = NULL;
    context->CSSetShaderResources(0, 1, srvs);

    context->CSSetShader(depthReductionCS, NULL, 0);

    for(uint32 i = 1; i < depthReductionTargets.size(); ++i)
    {
        RenderTarget2D& srcTexture = depthReductionTargets[i - 1];
        reductionConstants.Data.TextureSize.x = srcTexture.Width;
        reductionConstants.Data.TextureSize.y = srcTexture.Height;
        reductionConstants.Data.NumSamples = srcTexture.MultiSamples;
        reductionConstants.ApplyChanges(context);

        uavs[0] = depthReductionTargets[i].UAView;
        context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

        srvs[0] = srcTexture.SRView;
        context->CSSetShaderResources(0, 1, srvs);

        dispatchX = depthReductionTargets[i].Width;
        dispatchY = depthReductionTargets[i].Height;
        context->Dispatch(dispatchX, dispatchY, 1);

        uavs[0] = NULL;
        context->CSSetUnorderedAccessViews(0, 1, uavs, NULL);

        srvs[0] = NULL;
        context->CSSetShaderResources(0, 1, srvs);
    }

    // Copy to a staging texture
    ID3D11Texture2D* lastTarget = depthReductionTargets[depthReductionTargets.size() - 1].Texture;
    context->CopyResource(reductionStagingTextures[currFrame % ReadbackLatency].Texture, lastTarget);

    ++currFrame;

    if(currFrame >= ReadbackLatency)
    {
        StagingTexture2D& stagingTexture = reductionStagingTextures[currFrame % ReadbackLatency];

        uint32 pitch;
        const uint16* texData = reinterpret_cast<uint16*>(stagingTexture.Map(context, 0, pitch));
        reductionDepth.x = texData[0] / static_cast<float>(0xffff);
        reductionDepth.y = texData[1] / static_cast<float>(0xffff);

        stagingTexture.Unmap(context, 0);
    }
    else
    {
        reductionDepth = Float2(0.0f, 1.0f);
    }
}

// Convert to an EVSM map
void MeshRenderer::ConvertToEVSM(ID3D11DeviceContext* context, uint32 cascadeIdx, Float3 cascadeScale)
{
    PIXEvent event(L"EVSM Conversion");

    float blendFactor[4] = {1, 1, 1, 1};
    context->OMSetBlendState(blendStates.BlendDisabled(), blendFactor, 0xFFFFFFFF);
    context->RSSetState(rasterizerStates.NoCull());
    context->OMSetDepthStencilState(depthStencilStates.DepthDisabled(), 0);
    ID3D11Buffer* vbs[1] = { NULL };
    uint32 strides[1] = { 0 };
    uint32 offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vbs, strides, offsets);
    context->IASetIndexBuffer(NULL, DXGI_FORMAT_R32_UINT, 0);
    context->IASetInputLayout(NULL);

    SetViewport(context, sunVSM.Width, sunVSM.Height);

    evsmConstants.Data.PositiveExponent = PositiveExponent;
    evsmConstants.Data.NegativeExponent = NegativeExponent;
    evsmConstants.Data.CascadeScale = meshPSConstants.Data.CascadeScales[cascadeIdx].To3D();
    evsmConstants.Data.FilterSize = 1.0f;
    evsmConstants.Data.ShadowMapSize.x = float(sunVSM.Width);
    evsmConstants.Data.ShadowMapSize.y = float(sunVSM.Height);
    evsmConstants.ApplyChanges(context);
    evsmConstants.SetPS(context, 0);

    context->VSSetShader(fullScreenVS, NULL, 0);
    context->PSSetShader(evsmConvertPS, NULL, 0);

    ID3D11RenderTargetView* rtvs[1] = { sunVSM.RTVArraySlices[cascadeIdx] };
    context->OMSetRenderTargets(1, rtvs, NULL);

    ID3D11ShaderResourceView* srvs[1] = { sunShadowDepthMap.SRView };
    context->PSSetShaderResources(0, 1, srvs);

    context->Draw(3, 0);

    srvs[0] = NULL;
    context->PSSetShaderResources(0, 1, srvs);

    const float FilterSizeU = std::max(FilterSize * cascadeScale.x, 1.0f);
    const float FilterSizeV = std::max(FilterSize * cascadeScale.y, 1.0f);

    if(FilterSizeU > 1.0f || FilterSizeV > 1.0f)
    {
        // Horizontal pass
        evsmConstants.Data.FilterSize = FilterSizeU;
        evsmConstants.ApplyChanges(context);

        uint32 sampleRadiusU = static_cast<uint32>((FilterSizeU / 2) + 0.499f);

        rtvs[0] = tempVSM.RTView;
        context->OMSetRenderTargets(1, rtvs, NULL);

        srvs[0] = sunVSM.SRVArraySlices[cascadeIdx];
        context->PSSetShaderResources(0, 1, srvs);

        context->PSSetShader(evsmBlurH, NULL, 0);

        context->Draw(3, 0);

        srvs[0] = NULL;
        context->PSSetShaderResources(0, 1, srvs);

        // Vertical pass
        evsmConstants.Data.FilterSize = FilterSizeV;
        evsmConstants.ApplyChanges(context);

        uint32 sampleRadiusV = static_cast<uint32>((FilterSizeV / 2) + 0.499f);

        rtvs[0] = sunVSM.RTVArraySlices[cascadeIdx];
        context->OMSetRenderTargets(1, rtvs, NULL);

        srvs[0] = tempVSM.SRView;
        context->PSSetShaderResources(0, 1, srvs);

        context->PSSetShader(evsmBlurV, NULL, 0);

        context->Draw(3, 0);

        srvs[0] = NULL;
        context->PSSetShaderResources(0, 1, srvs);
    }

    if(EnableShadowMips && cascadeIdx == NumCascades - 1)
        context->GenerateMips(sunVSM.SRView);
}

// Renders all meshes in the model, with shadows
void MeshRenderer::RenderMainPass(ID3D11DeviceContext* context, const Camera& camera, const MeshBakerStatus& status)
{
    PIXEvent event(L"Mesh Rendering");

    // Set states
    float blendFactor[4] = {1, 1, 1, 1};
    context->OMSetBlendState(blendStates.BlendDisabled(), blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(depthStencilStates.DepthEnabled(), 0);
    context->RSSetState(rasterizerStates.BackFaceCull());

    ID3D11SamplerState* sampStates[] = {
        samplerStates.Anisotropic(),
        evsmSampler,
        samplerStates.LinearClamp(),
        samplerStates.ReversedShadowMapPCF(),
    };

    context->PSSetSamplers(0, ArraySize_(sampStates), sampStates);

    // Set constant buffers
    meshVSConstants.Data.World = Float4x4();
    meshVSConstants.Data.View = Float4x4::Transpose(camera.ViewMatrix());
    meshVSConstants.Data.WorldViewProjection = Float4x4::Transpose(camera.ViewProjectionMatrix());
    meshVSConstants.Data.PrevWorldViewProjection = Float4x4::Transpose(prevVP);
    meshVSConstants.ApplyChanges(context);
    meshVSConstants.SetVS(context, 0);

    meshPSConstants.Data.SunDirectionWS = AppSettings::SunDirection;
    meshPSConstants.Data.SunIlluminance = AppSettings::SunIlluminance();
    meshPSConstants.Data.CosSunAngularRadius = std::cos(DegToRad(AppSettings::SunSize) / 2.0f);
    meshPSConstants.Data.SinSunAngularRadius = std::sin(DegToRad(AppSettings::SunSize) / 2.0f);
    meshPSConstants.Data.CameraPosWS = camera.Position();
    meshPSConstants.Data.OffsetScale = OffsetScale;
    meshPSConstants.Data.PositiveExponent = PositiveExponent;
    meshPSConstants.Data.NegativeExponent = NegativeExponent;
    meshPSConstants.Data.LightBleedingReduction = LightBleedingReduction;
    for(uint64 i = 0; i < ArraySize_(status.SGDirections); ++i)
        meshPSConstants.Data.SGDirections[i] = Float4(status.SGDirections[i], 0.0f);
    meshPSConstants.Data.SGSharpness = status.SGSharpness;
    meshPSConstants.ApplyChanges(context);
    meshPSConstants.SetPS(context, 0);

    // Set shaders
    context->DSSetShader(nullptr, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->VSSetShader(meshVS, nullptr, 0);
    context->PSSetShader(meshPS, nullptr, 0);

    // Draw all meshes
    for(uint64 meshIdx = 0; meshIdx < sceneModel->Meshes().size(); ++meshIdx)
    {
        const Mesh& mesh = sceneModel->Meshes()[meshIdx];

        // Set the vertices and indices
        ID3D11Buffer* vertexBuffers[1] = { mesh.VertexBuffer() };
        UINT vertexStrides[1] = { mesh.VertexStride() };
        UINT offsets[1] = { 0 };
        context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
        context->IASetIndexBuffer(mesh.IndexBuffer(), mesh.IndexBufferFormat(), 0);
        context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        // Set the input layout
        context->IASetInputLayout(meshInputLayouts[meshIdx]);

        // Draw all parts
        for(uint64 partIdx = 0; partIdx < mesh.MeshParts().size(); ++partIdx)
        {
            const MeshPart& part = mesh.MeshParts()[partIdx];
            const MeshMaterial& material = sceneModel->Materials()[part.MaterialIdx];

            // Set the textures
            ID3D11ShaderResourceView* psTextures[] =
            {
                material.DiffuseMap,
                material.NormalMap,
                material.RoughnessMap,
                material.MetallicMap,
                sunVSM.SRView,
                status.LightMap,
                areaLightShadowMap.SRView,
                shSpecularLookupA,
                shSpecularLookupB,
                envSpecularLookup,
            };

            context->PSSetShaderResources(0, ArraySize_(psTextures), psTextures);
            context->DrawIndexed(part.IndexCount, part.IndexStart, 0);
        }
    }

    ID3D11ShaderResourceView* nullSRVs[10] = { NULL };
    context->PSSetShaderResources(0, ArraySize_(nullSRVs), nullSRVs);
}

// Renders all meshes using depth-only rendering
void MeshRenderer::RenderDepth(ID3D11DeviceContext* context, const Camera& camera, bool noZClip, bool flippedZRange)
{
    PIXEvent event(L"Mesh Depth Rendering");

    // Set states
    float blendFactor[4] = {1, 1, 1, 1};
    context->OMSetBlendState(blendStates.ColorWriteDisabled(), blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(flippedZRange ? depthStencilStates.ReverseDepthWriteEnabled()
                                                  : depthStencilStates.DepthWriteEnabled(), 0);

    if(noZClip)
        context->RSSetState(noZClipRSState);
    else
        context->RSSetState(rasterizerStates.BackFaceCull());

    // Set constant buffers
    meshVSConstants.Data.World = Float4x4();
    meshVSConstants.Data.View = Float4x4::Transpose(camera.ViewMatrix());
    meshVSConstants.Data.WorldViewProjection = Float4x4::Transpose(camera.ViewProjectionMatrix());
    meshVSConstants.ApplyChanges(context);
    meshVSConstants.SetVS(context, 0);

    // Set shaders
    context->VSSetShader(meshDepthVS , nullptr, 0);
    context->PSSetShader(nullptr, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->DSSetShader(nullptr, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);

    for(uint32 meshIdx = 0; meshIdx < sceneModel->Meshes().size(); ++meshIdx)
    {
        const Mesh& mesh = sceneModel->Meshes()[meshIdx];

        // Set the vertices and indices
        ID3D11Buffer* vertexBuffers[1] = { mesh.VertexBuffer() };
        UINT vertexStrides[1] = { mesh.VertexStride() };
        UINT offsets[1] = { 0 };
        context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
        context->IASetIndexBuffer(mesh.IndexBuffer(), mesh.IndexBufferFormat(), 0);
        context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

        // Set the input layout
        context->IASetInputLayout(meshDepthInputLayouts[meshIdx]);

        // Draw all parts
        for(uint64 partIdx = 0; partIdx < mesh.MeshParts().size(); ++partIdx)
        {
            const MeshPart& part = mesh.MeshParts()[partIdx];
            context->DrawIndexed(part.IndexCount, part.IndexStart, 0);
        }
    }
}

// Renders meshes using cascaded shadow mapping
void MeshRenderer::RenderSunShadowMap(ID3D11DeviceContext* context, const Camera& camera)
{
    PIXEvent event(L"Sun Shadow Map Rendering");

    const float MinDistance = reductionDepth.x;
    const float MaxDistance = reductionDepth.y;

    // Compute the split distances based on the partitioning mode
    float CascadeSplits[4] = { 0.0f, 0.0f, 0.0f, 0.0f };

    {
        float lambda = 1.0f;

        float nearClip = camera.NearClip();
        float farClip = camera.FarClip();
        float clipRange = farClip - nearClip;

        float minZ = nearClip + MinDistance * clipRange;
        float maxZ = nearClip + MaxDistance * clipRange;

        float range = maxZ - minZ;
        float ratio = maxZ / minZ;

        for(uint32 i = 0; i < NumCascades; ++i)
        {
            float p = (i + 1) / static_cast<float>(NumCascades);
            float log = minZ * std::pow(ratio, p);
            float uniform = minZ + range * p;
            float d = lambda * (log - uniform) + uniform;
            CascadeSplits[i] = (d - nearClip) / clipRange;
        }
    }

    Float3 c0Extents;
    Float4x4 c0Matrix;

    const Float3 lightDir = AppSettings::SunDirection;

    // Render the meshes to each cascade
    for(uint32 cascadeIdx = 0; cascadeIdx < NumCascades; ++cascadeIdx)
    {
        PIXEvent cascadeEvent((L"Rendering Shadow Map Cascade " + ToString(cascadeIdx)).c_str());

        // Set the viewport
        SetViewport(context, ShadowMapSize, ShadowMapSize);

        // Set the shadow map as the depth target
        ID3D11DepthStencilView* dsv = sunShadowDepthMap.DSView;
        ID3D11RenderTargetView* nullRenderTargets[D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT] = { NULL };
        context->OMSetRenderTargets(D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT, nullRenderTargets, dsv);
        context->ClearDepthStencilView(dsv, D3D11_CLEAR_DEPTH|D3D11_CLEAR_STENCIL, 1.0f, 0);

        // Get the 8 points of the view frustum in world space
        XMVECTOR frustumCornersWS[8] =
        {
            XMVectorSet(-1.0f,  1.0f, 0.0f, 1.0f),
            XMVectorSet( 1.0f,  1.0f, 0.0f, 1.0f),
            XMVectorSet( 1.0f, -1.0f, 0.0f, 1.0f),
            XMVectorSet(-1.0f, -1.0f, 0.0f, 1.0f),
            XMVectorSet(-1.0f,  1.0f, 1.0f, 1.0f),
            XMVectorSet( 1.0f,  1.0f, 1.0f, 1.0f),
            XMVectorSet( 1.0f, -1.0f, 1.0f, 1.0f),
            XMVectorSet(-1.0f, -1.0f, 1.0f, 1.0f),
        };

        float prevSplitDist = cascadeIdx == 0 ? MinDistance : CascadeSplits[cascadeIdx - 1];
        float splitDist = CascadeSplits[cascadeIdx];

        XMVECTOR det;
        XMMATRIX invViewProj = XMMatrixInverse(&det, camera.ViewProjectionMatrix().ToSIMD());
        for(uint32 i = 0; i < 8; ++i)
            frustumCornersWS[i] = XMVector3TransformCoord(frustumCornersWS[i], invViewProj);

        // Get the corners of the current cascade slice of the view frustum
        for(uint32 i = 0; i < 4; ++i)
        {
            XMVECTOR cornerRay = XMVectorSubtract(frustumCornersWS[i + 4], frustumCornersWS[i]);
            XMVECTOR nearCornerRay = XMVectorScale(cornerRay, prevSplitDist);
            XMVECTOR farCornerRay = XMVectorScale(cornerRay, splitDist);
            frustumCornersWS[i + 4] = XMVectorAdd(frustumCornersWS[i], farCornerRay);
            frustumCornersWS[i] = XMVectorAdd(frustumCornersWS[i], nearCornerRay);
        }

        // Calculate the centroid of the view frustum slice
        XMVECTOR frustumCenterVec = XMVectorZero();
        for(uint32 i = 0; i < 8; ++i)
            frustumCenterVec = XMVectorAdd(frustumCenterVec, frustumCornersWS[i]);
        frustumCenterVec = XMVectorScale(frustumCenterVec, 1.0f / 8.0f);
        Float3 frustumCenter = frustumCenterVec;

        // Pick the up vector to use for the light camera
        Float3 upDir = camera.Right();

        Float3 minExtents;
        Float3 maxExtents;

        {
            // Create a temporary view matrix for the light
            Float3 lightCameraPos = frustumCenter;
            Float3 lookAt = frustumCenter - lightDir;
            XMMATRIX lightView = XMMatrixLookAtLH(lightCameraPos.ToSIMD(), lookAt.ToSIMD(), upDir.ToSIMD());

            // Calculate an AABB around the frustum corners
            XMVECTOR mins = XMVectorSet(REAL_MAX, REAL_MAX, REAL_MAX, REAL_MAX);
            XMVECTOR maxes = XMVectorSet(-REAL_MAX, -REAL_MAX, -REAL_MAX, -REAL_MAX);
            for(uint32 i = 0; i < 8; ++i)
            {
                XMVECTOR corner = XMVector3TransformCoord(frustumCornersWS[i], lightView);
                mins = XMVectorMin(mins, corner);
                maxes = XMVectorMax(maxes, corner);
            }

            minExtents = mins;
            maxExtents = maxes;
        }

        // Adjust the min/max to accommodate the filtering size
        float scale = (ShadowMapSize + FilterSize) / static_cast<float>(ShadowMapSize);
        minExtents.x *= scale;
        minExtents.y *= scale;
        maxExtents.x *= scale;
        maxExtents.y *= scale;

        Float3 cascadeExtents = maxExtents - minExtents;

        // Get position of the shadow camera
        Float3 shadowCameraPos = frustumCenter + lightDir * -minExtents.z;

        // Come up with a new orthographic camera for the shadow caster
        OrthographicCamera shadowCamera(minExtents.x, minExtents.y, maxExtents.x,
            maxExtents.y, 0.0f, cascadeExtents.z);
        shadowCamera.SetLookAt(shadowCameraPos, frustumCenter, upDir);

        // Draw the mesh with depth only, using the new shadow camera
        RenderDepth(context, shadowCamera, true, false);

        // Apply the scale/offset matrix, which transforms from [-1,1]
        // post-projection space to [0,1] UV space
        XMMATRIX texScaleBias;
        texScaleBias.r[0] = XMVectorSet(0.5f,  0.0f, 0.0f, 0.0f);
        texScaleBias.r[1] = XMVectorSet(0.0f, -0.5f, 0.0f, 0.0f);
        texScaleBias.r[2] = XMVectorSet(0.0f,  0.0f, 1.0f, 0.0f);
        texScaleBias.r[3] = XMVectorSet(0.5f,  0.5f, 0.0f, 1.0f);
        XMMATRIX shadowMatrix = shadowCamera.ViewProjectionMatrix().ToSIMD();
        shadowMatrix = XMMatrixMultiply(shadowMatrix, texScaleBias);

        // Store the split distance in terms of view space depth
        const float clipDist = camera.FarClip() - camera.NearClip();
        meshPSConstants.Data.CascadeSplits[cascadeIdx] = camera.NearClip() + splitDist * clipDist;

        if(cascadeIdx == 0)
        {
            c0Extents = cascadeExtents;
            c0Matrix = shadowMatrix;
            meshPSConstants.Data.ShadowMatrix = XMMatrixTranspose(shadowMatrix);
            meshPSConstants.Data.CascadeOffsets[0] = Float4(0.0f, 0.0f, 0.0f, 0.0f);
            meshPSConstants.Data.CascadeScales[0] = Float4(1.0f, 1.0f, 1.0f, 1.0f);
        }
        else
        {
            // Calculate the position of the lower corner of the cascade partition, in the UV space
            // of the first cascade partition
            Float4x4 invCascadeMat = Float4x4::Invert(shadowMatrix);
            Float3 cascadeCorner = Float3::Transform(Float3(0.0f, 0.0f, 0.0f), invCascadeMat);
            cascadeCorner = Float3::Transform(cascadeCorner, c0Matrix);

            // Do the same for the upper corner
            Float3 otherCorner = Float3::Transform(Float3(1.0f, 1.0f, 1.0f), invCascadeMat);
            otherCorner = Float3::Transform(otherCorner, c0Matrix);

            // Calculate the scale and offset
            Float3 cascadeScale = Float3(1.0f, 1.0f, 1.f) / (otherCorner - cascadeCorner);
            meshPSConstants.Data.CascadeOffsets[cascadeIdx] = Float4(-cascadeCorner, 0.0f);
            meshPSConstants.Data.CascadeScales[cascadeIdx] = Float4(cascadeScale, 1.0f);
        }

        ConvertToEVSM(context, cascadeIdx, meshPSConstants.Data.CascadeScales[cascadeIdx].To3D());
    }
}

// Renders an omni-directional shadow map for the spherical area light
void MeshRenderer::RenderAreaLightShadowMap(ID3D11DeviceContext* context, const Camera& camera)
{
    PIXEvent event(L"Area Light Shadow Map Rendering");

    const uint32 sMapSize = areaLightShadowMap.Width;
    const Float3 areaLightPos = Float3(AppSettings::AreaLightX, AppSettings::AreaLightY, AppSettings::AreaLightZ);
    const float nearClip = AppSettings::AreaLightSize;

    for(uint64 face = 0; face < 6; ++face)
    {
        PIXEvent faceEvent(L"Area Light Shadow Map Face " + ToString(face));

        // Set the viewport
        SetViewport(context, sMapSize, sMapSize);

        // Set the shadow map as the depth target
        ID3D11DepthStencilView* dsv = areaLightShadowMap.ArraySlices[face];
        ID3D11RenderTargetView* nullRenderTargets[D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT] = { NULL };
        context->OMSetRenderTargets(D3D11_SIMULTANEOUS_RENDER_TARGET_COUNT, nullRenderTargets, dsv);
        context->ClearDepthStencilView(dsv, D3D11_CLEAR_DEPTH|D3D11_CLEAR_STENCIL, 0.0f, 0);

        PerspectiveCamera shadowCamera(1.0f, Pi_2, nearClip, nearClip + 1.0f);

        // Set up a infinite reverse projection
        Float4x4 projection;
        projection._33 = 0.0f;
        projection._43 = nearClip;
        projection._34 = 1.0f;
        projection._44 = 0.0f;
        shadowCamera.SetProjection(projection);

        static const Float3 LookAtDirs[6] =
        {
            Float3(1.0f, 0.0f, 0.0f), Float3(-1.0f, 0.0f, 0.0f),
            Float3(0.0f, 1.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f),
            Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, 0.0f, -1.0f)
        };

        static const Float3 UpDirs[6] = {
            Float3(0.0f, 1.0f, 0.0f),  Float3(0.0f, 1.0f, 0.0f),
            Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, 0.0f, 1.0f),
            Float3(0.0f, 1.0f, 0.0f),  Float3(0.0f, 1.0f, 0.0f),
        };

        shadowCamera.SetLookAt(areaLightPos, areaLightPos + LookAtDirs[face], UpDirs[face]);

        RenderDepth(context, shadowCamera, false, true);
    }
}

// Renders the area light
void MeshRenderer::RenderAreaLight(ID3D11DeviceContext* context, const Camera& camera)
{
    PIXEvent event(L"Area Light Rendering");

    // Set states
    float blendFactor[4] = {1, 1, 1, 1};
    context->OMSetBlendState(blendStates.BlendDisabled(), blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(depthStencilStates.DepthWriteEnabled(), 0);
    context->RSSetState(rasterizerStates.NoCull());

    // Set constant buffers
    areaLightConstants.Data.ViewProjection = Float4x4::Transpose(camera.ViewProjectionMatrix());
    areaLightConstants.Data.PrevViewProjection = Float4x4::Transpose(prevVP);
    areaLightConstants.ApplyChanges(context);
    areaLightConstants.SetVS(context, 0);
    areaLightConstants.SetPS(context, 0);

    // Set shaders
    context->DSSetShader(nullptr, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->VSSetShader(areaLightVS , nullptr, 0);
    context->PSSetShader(areaLightPS, nullptr, 0);

    // Draw the visualizer sphere
    ID3D11Buffer* vertexBuffers[1] = { areaLightVB };
    uint32 vertexStrides[1] = { sizeof(Float3) };
    uint32 offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
    context->IASetIndexBuffer(areaLightIB, DXGI_FORMAT_R32_UINT, 0);
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    context->IASetInputLayout(areaLightInputLayout);
    context->DrawIndexedInstanced(uint32(numAreaLightIndices), 1, 0, 0, 0);
}

// Renders the bake data visualizer
void MeshRenderer::RenderBakeDataVisualizer(ID3D11DeviceContext* context, const Camera& camera, const MeshBakerStatus& status)
{
    PIXEvent event(L"Bake Data Visualizer");

    // Set states
    float blendFactor[4] = {1, 1, 1, 1};
    context->OMSetBlendState(blendStates.BlendDisabled(), blendFactor, 0xFFFFFFFF);
    context->OMSetDepthStencilState(depthStencilStates.DepthWriteEnabled(), 0);
    context->RSSetState(rasterizerStates.NoCull());

    // Set constant buffers
    visualizerConstants.Data.ViewProjection = Float4x4::Transpose(camera.ViewProjectionMatrix());
    for(uint64 i = 0; i < ArraySize_(status.SGDirections); ++i)
        visualizerConstants.Data.SGDirections[i] = Float4(status.SGDirections[i], 0.0f);
    visualizerConstants.Data.SGSharpness = status.SGSharpness;
    visualizerConstants.ApplyChanges(context);
    visualizerConstants.SetVS(context, 0);
    visualizerConstants.SetPS(context, 0);

    // Set shaders
    context->DSSetShader(nullptr, nullptr, 0);
    context->HSSetShader(nullptr, nullptr, 0);
    context->GSSetShader(nullptr, nullptr, 0);
    context->VSSetShader(visualizerVS , nullptr, 0);
    context->PSSetShader(visualizerPS, nullptr, 0);

    ID3D11ShaderResourceView* vsSrvs[] = { status.BakePoints };
    context->VSSetShaderResources(0, ArraySize_(vsSrvs), vsSrvs);

    ID3D11ShaderResourceView* psSrvs[1] = { status.LightMap };
    context->PSSetShaderResources(0, 1, psSrvs);

    // Draw the visualizer hemispheres for all sample points
    ID3D11Buffer* vertexBuffers[1] = { hemisphereVB };
    uint32 vertexStrides[1] = { sizeof(Float3) };
    uint32 offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
    context->IASetIndexBuffer(hemisphereIB, DXGI_FORMAT_R32_UINT, 0);
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    context->IASetInputLayout(visualizerInputLayout);

    // Draw
    context->DrawIndexedInstanced(uint32(numHemisphereIndices), uint32(status.NumBakePoints), 0, 0, 0);

    ID3D11ShaderResourceView* nullSRVs[] = { nullptr };
    context->VSSetShaderResources(0, 1, nullSRVs);
    context->PSSetShaderResources(0, 1, nullSRVs);
}