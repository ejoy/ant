//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Includes
//=================================================================================================
#include <Constants.hlsl>
#include "AppSettings.hlsl"

//=================================================================================================
// Constant buffers
//=================================================================================================
cbuffer Constants : register(b0)
{
    float4x4 ViewProjection;
    float4x4 PrevViewProjection;
    float2 RTSize;
    float2 JitterOffset;
}

//=================================================================================================
// Input/output structures
//=================================================================================================
struct VSOutput
{
    float4 Position : SV_Position;
    float3 PrevPosition : PREVPOSITION;
};

struct PSOutput
{
    float4 Color : SV_Target0;
    float2 Velocity : SV_Target1;
};

//=================================================================================================
// Vertex shader
//=================================================================================================
VSOutput VS(in float3 SpherePosition : POSITION, in uint InstanceID : SV_InstanceID)
{
    float3 vertexPos = SpherePosition;
    if(InstanceID == 1)
        vertexPos.z *= -1.0f;
    vertexPos *= AreaLightSize;
    vertexPos += float3(AreaLightX, AreaLightY, AreaLightZ);

    VSOutput output;
    output.Position = mul(float4(vertexPos, 1.0f), ViewProjection);
    output.PrevPosition = mul(float4(vertexPos, 1.0f), PrevViewProjection).xyw;

    return output;
}

//=================================================================================================
// Pixel shader
//=================================================================================================
PSOutput PS(in VSOutput input)
{
    PSOutput output;
    output.Color.xyz = clamp(AreaLightColor * FP16Scale, 0.0f, FP16Max);
    output.Color.w = 1.0f;

    float2 prevPosition = (input.PrevPosition.xy / input.PrevPosition.z) * float2(0.5f, -0.5f) + 0.5f;
    prevPosition *= RTSize;
    output.Velocity = input.Position.xy - prevPosition;
    output.Velocity -= JitterOffset;
    output.Velocity /= RTSize;

    return output;
}