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
#include "SharedConstants.h"
#include "AppSettings.hlsl"

//=================================================================================================
// Resources
//=================================================================================================
cbuffer BackgroundVelocityConstants : register(b0)
{
    float4x4 InvViewProjection;
    float4x4 PrevViewProjection;
    float2 RTSize;
    float2 JitterOffset;
};

float4 BackgroundVelocityVS(in uint VertexID : SV_VertexID) : SV_Position
{
    float4 output = 0.0f;

    if(VertexID == 0)
        output = float4(-1.0f, 1.0f, 1.0f, 1.0f);
    else if(VertexID == 1)
        output = float4(3.0f, 1.0f, 1.0f, 1.0f);
    else
        output = float4(-1.0f, -3.0f, 1.0f, 1.0f);

    return output;
}

float2 BackgroundVelocityPS(in float4 PositionSS : SV_Position) : SV_Target0
{
    float4 positionNCD = float4((PositionSS.xy / RTSize) * 2.0f - 1.0f, 1.0f, 1.0f);
    positionNCD.y *= -1.0f;
    float4 positionWS = mul(positionNCD, InvViewProjection);
    positionWS /= positionWS.w;
    float4 prevPositionNCD = mul(float4(positionWS.xyz, 1.0f), PrevViewProjection);
    prevPositionNCD /= prevPositionNCD.w;
    float2 prevPositionSS = (prevPositionNCD.xy * float2(0.5f, -0.5f) + 0.5f) * RTSize;
    float2 velocity = PositionSS.xy - prevPositionSS;
    velocity -= JitterOffset;
    return velocity / RTSize;
}