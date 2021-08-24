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

#include "..\\Exceptions.h"
#include "..\\Utility.h"
#include "..\\InterfacePointers.h"
#include "..\\SF11_Math.h"
#include "ShaderCompilation.h"

namespace SampleFramework11
{

class SpriteFont;

class SpriteRenderer
{

public:

    enum FilterMode
    {
        DontSet = 0,
        Linear = 1,
        Point = 2
    };

    enum BlendMode
    {
        AlphaBlend = 0,
        OpaqueBlend = 1,
    };

    static const uint64 MaxBatchSize = 1000;

    struct SpriteDrawData
    {
        Float4x4 Transform;
        Float4 Color;
        Float4 DrawRect;
    };

    SpriteRenderer();
    ~SpriteRenderer();

    void Initialize(ID3D11Device* device);

    void Begin(ID3D11DeviceContext* deviceContext, FilterMode filterMode = DontSet, BlendMode = AlphaBlend);

    void Render(ID3D11ShaderResourceView* texture,
                const Float4x4& transform,
                const Float4& color = Float4(1, 1, 1, 1),
                const Float4* drawRect = NULL);

    void RenderBatch(ID3D11ShaderResourceView* texture,
                     const SpriteDrawData* drawData,
                     uint64 numSprites);

    void RenderText(const SpriteFont& font,
                    const wchar* text,
                    const Float4x4& transform,
                    const Float4& color = Float4(1, 1, 1, 1));

    void End();

protected:

    D3D11_TEXTURE2D_DESC SetPerBatchData(ID3D11ShaderResourceView* texture);

    ID3D11DevicePtr device;
    VertexShaderPtr vertexShader;
    VertexShaderPtr vertexShaderInstanced;
    PixelShaderPtr pixelShader;
    PixelShaderPtr pixelShaderOpaque;
    ID3D11BufferPtr vertexBuffer;
    ID3D11BufferPtr indexBuffer;
    ID3D11BufferPtr vsPerBatchCB;
    ID3D11BufferPtr vsPerInstanceCB;
    ID3D11BufferPtr instanceDataBuffer;
    ID3D11InputLayoutPtr inputLayout;
    ID3D11InputLayoutPtr inputLayoutInstanced;
    ID3D11DeviceContextPtr context;

    ID3D11RasterizerStatePtr rastState;
    ID3D11DepthStencilStatePtr dsState;
    ID3D11BlendStatePtr alphaBlendState;
    ID3D11BlendStatePtr opaqueBlendState;
    ID3D11SamplerStatePtr linearSamplerState;
    ID3D11SamplerStatePtr pointSamplerState;

    bool initialized;

    SpriteDrawData textDrawData [MaxBatchSize];

    struct SpriteVertex
    {
        Float2 Position;
        Float2 TexCoord;
    };

    struct VSPerBatchCB
    {
        Float2 TextureSize;
        Float2 ViewportSize;
    };
};

}