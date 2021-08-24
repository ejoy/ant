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
#include <SF11_Math.h>
#include <InterfacePointers.h>
#include <Containers.h>
#include <Graphics/Textures.h>
#include <Graphics/ShaderCompilation.h>
#include <Graphics/SH.h>
#include <Graphics/Skybox.h>

#include "PathTracer.h"
#include "SharedConstants.h"
#include "AppSettings.h"

namespace SampleFramework11
{
    class Model;
    class Camera;
    struct StructuredBuffer;
}

using namespace SampleFramework11;

struct RenderThreadContext;
struct RenderThreadData;
struct IntegrationSamples;
struct BakeThreadData;
struct GutterTexel;
struct Vertex;

// Input to the baker
struct BakeInputData
{
    const Model* SceneModel = nullptr;
    ID3D11Device* Device = nullptr;
    ID3D11ShaderResourceView* EnvMaps[AppSettings::NumCubeMaps];
    TextureData<Half4> EnvMapData[AppSettings::NumCubeMaps];

    BakeInputData()
    {
        for(uint64 i = 0; i < ArraySize_(EnvMaps); ++i)
            EnvMaps[i] = nullptr;
    }
};

struct MeshBakerStatus
{
    ID3D11ShaderResourceView* GroundTruth = nullptr;
    ID3D11ShaderResourceView* LightMap = nullptr;
    ID3D11ShaderResourceView* BakePoints = nullptr;
    uint64 NumBakePoints = 0;
    float GroundTruthProgress = 0.0f;
    float BakeProgress = 0.0f;
    uint64 GroundTruthSampleCount = 0;
    Float3 SGDirections[AppSettings::MaxSGCount];
    float SGSharpness = 0.0f;
};

class MeshBaker
{

public:

    MeshBaker();
    ~MeshBaker();

    void Initialize(const BakeInputData& inputData);
    void Shutdown();

    MeshBakerStatus Update(const Camera& camera, uint32 screenWidth, uint32 screenHeight,
                           ID3D11DeviceContext* deviceContext, const Model* currentModel);

    // Read/Write Data shared with render threads
    FixedArray<Half4> renderBuffer;
    FixedArray<float> renderWeightBuffer;
    volatile int64 currTile = 0;

    // Read-only data shared with render threads
    volatile int64 renderTag = 0;
    uint32 currWidth = 0;
    uint32 currHeight = 0;
    Float3 currCameraPos;
    Quaternion currCameraOrientation;
    Float4x4 currProj;
    Float4x4 currViewProjInv;
    bool killRenderThreads = false;
    uint64 currNumTiles = 0;

    // Read/Write data shared with bake threads
    FixedArray<Float4> bakeResults[AppSettings::MaxBasisCount];
    volatile int64 currBakeBatch = 0;

    // Read-only data shared with bake threads
    volatile int64 bakeTag = 0;
    bool killBakeThreads = false;
    uint64 currNumBakeBatches = 0;
    uint64 currLightMapSize = 0;
    BakeModes currBakeMode = BakeModes::Diffuse;
    SolveModes currSolveMode = SolveModes::NNLS;
    std::vector<BakePoint> bakePoints;
    std::vector<GutterTexel> gutterTexels;

    // Read-only data shared with both bake and render threads
    BVHData sceneBVH;
    TextureData<Half4> envMap;
    BakeInputData input;

private:

    void KillBakeThreads();
    void StartBakeThreads();

    void KillRenderThreads();
    void StartRenderThreads();

    bool initialized = false;

    RTCDevice rtcDevice = nullptr;

    Random rng;

    static const uint64 NumStagingTextures = 2;

    ID3D11Texture2DPtr renderTexture;
    ID3D11ShaderResourceViewPtr renderTextureSRV;
    ID3D11Texture2DPtr renderStagingTextures[NumStagingTextures];
    uint64 renderStagingTextureIdx = 0;

    std::vector<HANDLE> renderThreads;
    std::vector<RenderThreadData> renderThreadData;
    std::vector<IntegrationSamples> renderSamples;
    SampleModes renderSampleMode = SampleModes::Random;
    uint64 numRenderSamples = 0;

    bool renderThreadsSuspended = false;

    ID3D11Texture2DPtr bakeTexture;
    ID3D11ShaderResourceViewPtr bakeTextureSRV;
    uint64 bakeStagingTextureIdx = 0;
    ID3D11Texture2DPtr bakeStagingTextures[NumStagingTextures];
    uint64 bakeTextureUpdateIdx = 0;

    uint64 numThreads = 0;
    std::vector<HANDLE> bakeThreads;
    std::vector<BakeThreadData> bakeThreadData;
    std::vector<IntegrationSamples> bakeSamples;
    SampleModes bakeSampleMode = SampleModes::Random;
    uint64 numBakeSamples = 0;
    StructuredBuffer bakePointBuffer;
    bool bakeThreadsSuspended = false;

    Float3 sgDirections[AppSettings::MaxSGCount];
    float sgSharpness = 0.0f;

    int64 lastTileNum = INT64_MAX;
};