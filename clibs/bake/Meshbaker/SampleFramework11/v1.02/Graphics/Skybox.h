//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"

#include "..\\InterfacePointers.h"
#include "..\\SF11_Math.h"
#include "ShaderCompilation.h"
#include "GraphicsTypes.h"

// HosekSky forward declares
struct ArHosekSkyModelState;

namespace SampleFramework11
{

// Cached data for the procedural sky model
struct SkyCache
{
    ArHosekSkyModelState* StateR = nullptr;
    ArHosekSkyModelState* StateG = nullptr;
    ArHosekSkyModelState* StateB = nullptr;
    Float3 SunDirection;
    float Turbidity = 0.0f;
    Float3 Albedo;
    float Elevation = 0.0f;
    ID3D11ShaderResourceViewPtr CubeMap;

    void Init(Float3 sunDirection, Float3 groundAlbedo, float turbidity);
    void Shutdown();
    ~SkyCache();
};

class Skybox
{

public:

    Skybox();
    ~Skybox();

    void Initialize(ID3D11Device* device);

    void RenderEnvironmentMap(ID3D11DeviceContext* context,
                              ID3D11ShaderResourceView* environmentMap,
                              const Float4x4& view,
                              const Float4x4& projection,
                              Float3 scale = Float3(1.0f, 1.0f, 1.0f));

    void RenderSky(ID3D11DeviceContext* context,
                   Float3 sunDirection,
                   Float3 groundAlbedo,
                   Float3 sunColor,
                   float sunSize,
                   float turbidity,
                   const Float4x4& view,
                   const Float4x4& projection,
                   Float3 scale = Float3(1.0f, 1.0f, 1.0f));

    void RenderSimpleSky(ID3D11DeviceContext* context,
                         Float3 skyColor,
                         Float3 sunDirection,
                         Float3 sunColor,
                         float sunSize,
                         const Float4x4& view,
                         const Float4x4& projection,
                         Float3 scake = Float3(1.0f, 1.0f, 1.0f));

    static Float3 SampleSky(const SkyCache& cache, Float3 sampleDir);

protected:

    void RenderCommon(ID3D11DeviceContext* context,
                      ID3D11ShaderResourceView* environmentMap,
                      ID3D11PixelShader* ps,
                      const Float4x4& view,
                      const Float4x4& projection,
                      Float3 scale);

    static const uint64 NumIndices = 36;
    static const uint64 NumVertices = 8;

    struct VSConstants
    {
        Float4x4 View;
        Float4x4 Projection;
    };

    struct PSConstants
    {
        Float3 SunDirection = Float3(0.0f, 1.0f, 0.0f);
        bool32 EnableSun = false;
        Float3 SkyColor = 1.0f;
        Float4Align Float3 SunColor = 1.0f;
        float CosSunAngularRadius = 0.0f;
        Float3 Scale = 1.0f;
    };

    ID3D11DevicePtr device;
    VertexShaderPtr vertexShader;
    PixelShaderPtr emPixelShader;
    PixelShaderPtr simpleSkyPS;
    ID3D11InputLayoutPtr inputLayout;
    ID3D11BufferPtr vertexBuffer;
    ID3D11BufferPtr indexBuffer;
    ConstantBuffer<VSConstants> vsConstantBuffer;
    ConstantBuffer<PSConstants> psConstantBuffer;
    ID3D11DepthStencilStatePtr dsState;
    ID3D11BlendStatePtr blendState;
    ID3D11RasterizerStatePtr rastState;
    ID3D11SamplerStatePtr samplerState;

    SkyCache skyCache;
};

}