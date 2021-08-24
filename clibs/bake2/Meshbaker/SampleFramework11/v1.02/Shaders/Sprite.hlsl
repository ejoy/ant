//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Constant buffers
//=================================================================================================
cbuffer VSPerBatch : register (b0)
{
    float2 TextureSize : packoffset(c0.x);
    float2 ViewportSize : packoffset(c0.z);
}

cbuffer VSPerInstance : register (b1)
{
    float4x4 Transform : packoffset(c0);
    float4 Color : packoffset(c4);
    float4 SourceRect : packoffset(c5);
}

//=================================================================================================
// Samplers
//=================================================================================================
Texture2D	SpriteTexture : register(t0);
SamplerState SpriteSampler : register(s0);


//=================================================================================================
// Input/Output structs
//=================================================================================================
struct VSInput
{
    float2 Position : POSITION;
    float2 TexCoord : TEXCOORD;
};

struct VSInputInstanced
{
    float2 Position : POSITION;
    float2 TexCoord : TEXCOORD;
    float4x4 Transform : TRANSFORM;
    float4 Color : COLOR;
    float4 SourceRect : SOURCERECT;
};

struct VSOutput
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD;
    float4 Color : COLOR;
};

//-------------------------------------------------------------------------------------------------
// Functionality common to both vertex shaders
//-------------------------------------------------------------------------------------------------
VSOutput SpriteVSCommon(float2 position,
                        float2 texCoord,
                        float4x4 transform,
                        float4 color,
                        float4 sourceRect)
{
    // Scale the quad so that it's texture-sized
    float4 positionSS = float4(position * sourceRect.zw, 0.0f, 1.0f);

    // Apply transforms in screen space
    positionSS = mul(positionSS, transform);

    // Scale by the viewport size, flip Y, then rescale to device coordinates
    float4 positionDS = positionSS;
    positionDS.xy /= ViewportSize;
    positionDS = positionDS * 2 - 1;
    positionDS.y *= -1;

    // Figure out the texture coordinates
    float2 outTexCoord = texCoord;
    outTexCoord.xy *= sourceRect.zw / TextureSize;
    outTexCoord.xy += sourceRect.xy / TextureSize;

    VSOutput output;
    output.Position = positionDS;
    output.TexCoord = outTexCoord;
    output.Color = color;

    return output;
}

//=================================================================================================
// Vertex Shader, non-instanced
//=================================================================================================
VSOutput SpriteVS(in VSInput input)
{
    return SpriteVSCommon(input.Position, input.TexCoord, Transform, Color, SourceRect);
}

//=================================================================================================
// Vertex Shader, instanced
//=================================================================================================
VSOutput SpriteInstancedVS(in VSInputInstanced input)
{
    return SpriteVSCommon(input.Position, input.TexCoord,
                            transpose(input.Transform), input.Color, input.SourceRect);
}

//=================================================================================================
// Pixel Shader
//=================================================================================================
float4 SpritePS(in VSOutput input) : SV_Target
{
    float4 texColor = SpriteTexture.Sample(SpriteSampler, input.TexCoord);
    texColor = texColor * input.Color;
    texColor.rgb *= texColor.a;
    return texColor;
}

//=================================================================================================
// Pixel Shader for opaque rendering
//=================================================================================================
float4 SpriteOpaquePS(in VSOutput input) : SV_Target
{
    float4 texColor = SpriteTexture.Sample(SpriteSampler, input.TexCoord);
    texColor = texColor * input.Color;
    return texColor;
}