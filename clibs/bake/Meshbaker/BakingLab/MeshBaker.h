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

#include "PathTracer.h"
#include "BakeSetting.h"
#include "Light.h"

namespace SampleFramework11
{
    class Model;
    class Camera;
    struct StructuredBuffer;
}

using namespace SampleFramework11;

struct IntegrationSamples;
struct BakeThreadData;
struct GutterTexel;
struct Vertex;

// Input to the baker
struct BakeInputData
{
    const Model* SceneModel = nullptr;
    ID3D11Device* Device = nullptr;
    // ID3D11ShaderResourceView* EnvMaps[AppSettings::NumCubeMaps];
    // TextureData<Half4> EnvMapData[AppSettings::NumCubeMaps];
    Lights lights;

    BakeInputData()
    {
        // for(uint64 i = 0; i < ArraySize_(EnvMaps); ++i)
        //     EnvMaps[i] = nullptr;
    }
};

struct MeshBakerStatus
{
    uint64 NumBakePoints = 0;
    float BakeProgress = 0.0f;
    Float3 SGDirections[BakeSetting::MaxSGCount];
    float SGSharpness = 0.0f;
};

struct BakePoint
{
    Float3 Position;
    Float3 Normal;
    Float3 Tangent;
    Float3 Bitangent;
    Float2 Size;
    uint32 Coverage;
    Uint2 TexelPos;

    #if _WINDOWS
        BakePoint() : Coverage(0) {}
    #endif
};

struct BakeBatchData {
    volatile int64 batchIdx = 0;
    uint64 num = 0;
    uint64 numGroupsX = 0;
    uint64 numGroupsY = 0;
    uint64 lightmapSize = 0;

    void Update(uint16 lmsize) {
        numGroupsX = (lmsize + (BakeSetting::BakeGroupSizeX - 1)) / BakeSetting::BakeGroupSizeX;
        numGroupsY = (lmsize + (BakeSetting::BakeGroupSizeY - 1)) / BakeSetting::BakeGroupSizeY;

        num = GetBakeSetting().NumBakeBatches(numGroupsX, numGroupsY);

        lightmapSize = lmsize;
    }

    float Process() const {
        return Saturate(batchIdx / (num - 1.0f));
    }
};

class MeshBaker
{

public:

    MeshBaker();
    ~MeshBaker();

    void Initialize(const BakeInputData& inputData);
    void Shutdown();

    void SetBakeMesh(uint32 meshIdx);
    float Process() const {
        return bakeBatchData.Process();
    }

    MeshBakerStatus GetBakerStatus() const;
    
    void StartBake();
    void EndBake();

    // Read/Write data shared with bake threads
    FixedArray<Float4> bakeResults[BakeSetting::MaxBasisCount];

    BakeBatchData bakeBatchData;

    bool killBakeThreads = false;
    std::vector<BakePoint> bakePoints;
    std::vector<GutterTexel> gutterTexels;

    // Read-only data shared with both bake and render threads
    BVHData sceneBVH;
    TextureData<Half4> envMap;
    BakeInputData input;

    uint32 bakeMeshIdx = UINT32_MAX;
private:

    RTCDevice rtcDevice = nullptr;

    Random rng;

    std::vector<HANDLE> bakeThreads;
    std::vector<BakeThreadData> bakeThreadData;
    std::vector<IntegrationSamples> bakeSamples;

    Float3 sgDirections[BakeSetting::MaxSGCount];
    float sgSharpness = 0.0f;

    int64 lastTileNum = INT64_MAX;
};