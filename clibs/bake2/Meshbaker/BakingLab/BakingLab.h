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

#include <App.h>
#include <InterfacePointers.h>
#include <Input.h>
#include <Graphics/Camera.h>
#include <Graphics/Model.h>
#include <Graphics/SpriteFont.h>
#include <Graphics/SpriteRenderer.h>
#include <Graphics/Skybox.h>
#include <Graphics/GraphicsTypes.h>

#include "PostProcessor.h"
#include "MeshRenderer.h"
#include "MeshBaker.h"

using namespace SampleFramework11;

class BakingLab : public App
{

protected:

    FirstPersonCamera camera;

    SpriteFont font;
    SampleFramework11::SpriteRenderer spriteRenderer;
    Skybox skybox;
    ID3D11ShaderResourceViewPtr envMaps[AppSettings::NumCubeMaps];

    PostProcessor postProcessor;
    DepthStencilBuffer depthBuffer;
    RenderTarget2D colorTargetMSAA;
    RenderTarget2D colorResolveTarget;
    RenderTarget2D prevFrameTarget;
    RenderTarget2D velocityTargetMSAA;
    StagingTexture2D readbackTexture;

    // Model
    Model sceneModels[uint64(Scenes::NumValues)];
    MeshRenderer meshRenderer;
    MeshBaker meshBaker;

    MouseState mouseState;

    float GTSampleRateBuffer[64];
    uint64 GTSampleRateBufferIdx = 0;

    VertexShaderPtr resolveVS;
    PixelShaderPtr resolvePS[uint64(MSAAModes::NumValues)];

    VertexShaderPtr backgroundVelocityVS;
    PixelShaderPtr backgroundVelocityPS;
    Float4x4 prevViewProjection;

    Float2 jitterOffset;
    Float2 prevJitter;
    uint64 frameCount = 0;
    FirstPersonCamera unJitteredCamera;

    struct ResolveConstants
    {
        uint32 SampleRadius;
        bool32 EnableTemporalAA;
        Float2 TextureSize;
    };

    struct BackgroundVelocityConstants
    {
        Float4x4 InvViewProjection;
        Float4x4 PrevViewProjection;
        Float2 RTSize;
        Float2 JitterOffset;
    };

    ConstantBuffer<ResolveConstants> resolveConstants;
    ConstantBuffer<BackgroundVelocityConstants> backgroundVelocityConstants;

    virtual void Initialize() override;
    virtual void Render(const Timer& timer) override;
    virtual void Update(const Timer& timer) override;
    virtual void BeforeReset() override;
    virtual void AfterReset() override;

    void CreateRenderTargets();

    void RenderMainPass(const MeshBakerStatus& status);
    void RenderAA();
    void RenderBackgroundVelocity();
    void RenderHUD(const Timer& timer, float groundTruthProgress, float bakeProgress,
                   uint64 groundTruthSampleCount);

public:

    BakingLab();
};
