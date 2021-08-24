//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

cbuffer PSConstants : register(b0)
{
    float2 InputSize0;
    float2 InputSize1;
    float2 InputSize2;
    float2 InputSize3;
    float2 InputSize4;
    float2 InputSize5;
    float2 InputSize6;
    float2 InputSize7;
    float2 OutputSize;
}

SamplerState PointSampler : register(s0);
SamplerState LinearSampler : register(s1);
SamplerState LinearWrapSampler : register(s2);
SamplerState LinearBorderSampler : register(s3);
SamplerState PointBorderSampler : register(s4);

Texture2D InputTexture0 : register(t0);
Texture2D InputTexture1 : register(t1);
Texture2D InputTexture2 : register(t2);
Texture2D InputTexture3 : register(t3);
Texture2D InputTexture4 : register(t4);
Texture2D InputTexture5 : register(t5);
Texture2D InputTexture6 : register(t6);
Texture2D InputTexture7 : register(t7);

struct PSInput
{
    float4 PositionSS : SV_Position;
    float2 TexCoord : TEXCOORD;
};