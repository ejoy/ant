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

//#include <InterfacePointers.h>
//#include <Input.h>
//#include <Graphics/Camera.h>
//#include <Graphics/Model.h>
//#include <Graphics/SpriteFont.h>
//#include <Graphics/SpriteRenderer.h>
//#include <Graphics/Skybox.h>
//#include <Graphics/GraphicsTypes.h>

//#include "PostProcessor.h"

#include "MeshRenderer.h"
#include "MeshBaker.h"

#include <vector>

class BakingLab
{

protected:

    // FirstPersonCamera camera;

    // SpriteFont font;
    // SampleFramework11::SpriteRenderer spriteRenderer;
    // Skybox skybox;
    ID3D11ShaderResourceViewPtr envMaps[AppSettings::NumCubeMaps];

    //PostProcessor postProcessor;

    // DepthStencilBuffer depthBuffer;
    // RenderTarget2D colorTargetMSAA;
    // RenderTarget2D colorResolveTarget;
    // RenderTarget2D prevFrameTarget;
    // RenderTarget2D velocityTargetMSAA;
    // StagingTexture2D readbackTexture;

    struct Model {
        
    };
    std::vector<Model> sceneModels;
    MeshRenderer    meshRenderer;
    MeshBaker       meshBaker;

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
