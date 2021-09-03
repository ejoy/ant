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

#include <Graphics/Model.h>
#include <Graphics/GraphicsTypes.h>
#include <Graphics/DeviceStates.h>
#include <Graphics/Camera.h>
#include <Graphics/SH.h>
#include <Graphics/ShaderCompilation.h>

#include "AppSettings.h"

using namespace SampleFramework11;

struct MeshBakerStatus;

class MeshRenderer
{

protected:

    // Constants
    static const uint32 NumCascades = 4;
    static const uint32 ReadbackLatency = 1;

public:
MeshRenderer();

    void Initialize(ID3D11Device* device, ID3D11DeviceContext* context, const Model* sceneModel);
    void SetModel(const Model* model);

    void RenderDepth(ID3D11DeviceContext* context, const Camera& camera, bool noZClip, bool flippedZRange);
    void RenderMainPass(ID3D11DeviceContext* context, const Camera& camera, const MeshBakerStatus& status);

    void Update(const Camera& camera, Float2 jitterOffset);

    void OnResize(uint32 width, uint32 height);

    void ReduceDepth(ID3D11DeviceContext* context, DepthStencilBuffer& depthTarget,
                     const Camera& camera);

    void RenderSunShadowMap(ID3D11DeviceContext* context, const Camera& camera);
    void RenderAreaLightShadowMap(ID3D11DeviceContext* context, const Camera& camera);

    void RenderAreaLight(ID3D11DeviceContext* context, const Camera& camera);
    void RenderBakeDataVisualizer(ID3D11DeviceContext* context, const Camera& camera,
                                   const MeshBakerStatus& status);

protected:

    void LoadShaders();
    void CreateShadowMaps();
    void ConvertToEVSM(ID3D11DeviceContext* context, uint32 cascadeIdx, Float3 cascadeScale);

    ID3D11DevicePtr device;

    BlendStates blendStates;
    RasterizerStates rasterizerStates;
    DepthStencilStates depthStencilStates;
    SamplerStates samplerStates;

    const Model* sceneModel;

    DepthStencilBuffer sunShadowDepthMap;
    RenderTarget2D  sunVSM;
    RenderTarget2D tempVSM;

    DepthStencilBuffer areaLightShadowMap;

    ID3D11RasterizerStatePtr noZClipRSState;
    ID3D11SamplerStatePtr evsmSampler;

    std::vector<ID3D11InputLayoutPtr> meshInputLayouts;
    VertexShaderPtr meshVS;
    PixelShaderPtr meshPS;

    std::vector<ID3D11InputLayoutPtr> meshDepthInputLayouts;
    VertexShaderPtr meshDepthVS;

    ID3D11BufferPtr hemisphereVB;
    ID3D11BufferPtr hemisphereIB;
    uint64 numHemisphereIndices;

    ID3D11InputLayoutPtr visualizerInputLayout;
    VertexShaderPtr visualizerVS;
    PixelShaderPtr visualizerPS;

    ID3D11BufferPtr areaLightVB;
    ID3D11BufferPtr areaLightIB;
    uint64 numAreaLightIndices;

    VertexShaderPtr areaLightVS;
    PixelShaderPtr areaLightPS;
    ID3D11InputLayoutPtr areaLightInputLayout;

    VertexShaderPtr fullScreenVS;
    PixelShaderPtr evsmConvertPS;
    PixelShaderPtr evsmBlurH;
    PixelShaderPtr evsmBlurV;

    ComputeShaderPtr depthReductionInitialCS[2];
    ComputeShaderPtr depthReductionCS;
    std::vector<RenderTarget2D> depthReductionTargets;
    StagingTexture2D reductionStagingTextures[ReadbackLatency];
    uint32 currFrame;

    Float2 reductionDepth;

    Float4x4 prevVP;
    Float4x4 currVP;
    bool firstFrame = true;

    ID3D11ShaderResourceViewPtr shSpecularLookupA;
    ID3D11ShaderResourceViewPtr shSpecularLookupB;
    ID3D11ShaderResourceViewPtr envSpecularLookup;

    // Constant buffers
    struct MeshVSConstants
    {
        Float4Align Float4x4 World;
        Float4Align Float4x4 View;
        Float4Align Float4x4 WorldViewProjection;
        Float4Align Float4x4 PrevWorldViewProjection;
    };

    struct MeshPSConstants
    {
        Float4Align Float3 SunDirectionWS;
        float CosSunAngularRadius;
        Float4Align Float3 SunIlluminance;
        float SinSunAngularRadius;
        Float4Align Float3 CameraPosWS;

        Float4Align Float4x4 ShadowMatrix;
        Float4Align float CascadeSplits[NumCascades];

        Float4Align Float4 CascadeOffsets[NumCascades];
        Float4Align Float4 CascadeScales[NumCascades];

        float OffsetScale;
        float PositiveExponent;
        float NegativeExponent;
        float LightBleedingReduction;

        Float2 RTSize;
        Float2 JitterOffset;

        Float4Align Float4 SGDirections[AppSettings::MaxSGCount];
        float SGSharpness;
    };

    struct AreaLightConstants
    {
        Float4x4 ViewProjection;
        Float4x4 PrevViewProjection;
        Float2 RTSize;
        Float2 JitterOffset;
    };

    struct EVSMConstants
    {
        Float3 CascadeScale;
        float PositiveExponent;
        float NegativeExponent;
        float FilterSize;
        Float2 ShadowMapSize;
    };

    struct ReductionConstants
    {
        Float4x4 Projection;
        float NearClip;
        float FarClip;
        Uint2 TextureSize;
        uint32 NumSamples;
    };

    struct VisualizerConstants
    {
        Float4x4 ViewProjection;
        Float4Align Float4 SGDirections[AppSettings::MaxSGCount];
        float SGSharpness;
    };

    ConstantBuffer<MeshVSConstants> meshVSConstants;
    ConstantBuffer<MeshPSConstants> meshPSConstants;
    ConstantBuffer<AreaLightConstants> areaLightConstants;
    ConstantBuffer<VisualizerConstants> visualizerConstants;
    ConstantBuffer<EVSMConstants> evsmConstants;
    ConstantBuffer<ReductionConstants> reductionConstants;
};