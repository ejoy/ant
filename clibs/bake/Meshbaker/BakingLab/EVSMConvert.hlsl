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
#include "EVSM.hlsl"

//=================================================================================================
// Constants
//=================================================================================================
#ifndef MSAASamples_
    #define MSAASamples_ 1
#endif

#ifndef SampleRadius_
    #define SampleRadius_ 0
#endif

//=================================================================================================
// Resources
//=================================================================================================
#if MSAASamples_ > 1
    Texture2DMS<float> ShadowMap : register(t0);
#else
    Texture2D<float> ShadowMap : register(t0);
#endif

#if Vertical_
    Texture2D EVSMMap : register(t0);
#else
    Texture2DArray EVSMMap : register(t0);
#endif

cbuffer EVSMConstants : register(b0)
{
    float3 CascadeScale;
    float PositiveExponent;
    float NegativeExponent;
    float FilterSize;
    float2 ShadowMapSize;
}

struct VSOutput
{
    float4 Position : SV_Position;
    float2 TexCoord : TEXCOORD;
};

VSOutput FullScreenVS(in uint VertexID : SV_VertexID)
{
    VSOutput output;

    if(VertexID == 0)
    {
        output.Position = float4(-1.0f, 1.0f, 1.0f, 1.0f);
        output.TexCoord = float2(0.0f, 0.0f);
    }
    else if(VertexID == 1)
    {
        output.Position = float4(3.0f, 1.0f, 1.0f, 1.0f);
        output.TexCoord = float2(2.0f, 0.0f);
    }
    else
    {
        output.Position = float4(-1.0f, -3.0f, 1.0f, 1.0f);
        output.TexCoord = float2(0.0f, 2.0f);
    }

    return output;
}

float4 ConvertToEVSM(in VSOutput input) : SV_Target0
{
    float sampleWeight = 1.0f / float(MSAASamples_);
    uint2 coords = uint2(input.Position.xy);

    float2 exponents = GetEVSMExponents(PositiveExponent, NegativeExponent, CascadeScale);

    float4 average = float4(0.0f, 0.0f, 0.0f, 0.0f);

    // Sample indices to Load() must be literal, so force unroll
    [unroll]
    for(uint i = 0; i < MSAASamples_; ++i)
    {
        // Convert to EVSM representation
        #if MSAASamples_ > 1
            float depth = ShadowMap.Load(coords, i);
        #else
            float depth = ShadowMap[coords];
        #endif

        float2 warpedDepth = WarpDepth(depth, exponents);
        average += sampleWeight * float4(warpedDepth.xy, warpedDepth.xy * warpedDepth.xy);
    }

    return average;
}

float4 BlurSample(in float2 screenPos, in float offset, in float2 mapSize)
{
    #if Vertical_
        float2 samplePos = screenPos;
        samplePos.y = clamp(screenPos.y + offset, 0, mapSize.y);
        return EVSMMap[uint2(samplePos)];
    #else
        float2 samplePos = screenPos;
        samplePos.x = clamp(screenPos.x + offset, 0, mapSize.x);
        return EVSMMap[uint3(samplePos, 0)];
    #endif
}

float4 BlurEVSM(in VSOutput input) : SV_Target0
{
    const float Radius = FilterSize / 2.0f;

    float4 sum = 0.0f;

    [unroll]
    for(int i = -SampleRadius_; i <= SampleRadius_; ++i)
    {
        float4 sample = BlurSample(input.Position.xy, i, ShadowMapSize);

        sample *= saturate((Radius + 0.5f) - abs(i));

        sum += sample;
    }

    return sum / FilterSize;
}