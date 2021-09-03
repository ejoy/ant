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
#include <SH.hlsl>
#include "AppSettings.hlsl"
#include "SG.hlsl"

//=================================================================================================
// Constant buffers
//=================================================================================================
cbuffer Constants : register(b0)
{
    float4x4 ViewProjection;
    float4 SGDirections[MaxSGCount];
    float SGSharpness;
}

//=================================================================================================
// Resources
//=================================================================================================
StructuredBuffer<BakePoint> BakePoints : register(t0);
Texture2DArray<float4> BakedLightingMap : register(t0);
SamplerState LinearSampler : register(s0);

//=================================================================================================
// Input/Output structs
//=================================================================================================
struct VSOutput
{
    float4 PositionCS 		: SV_Position;
    float3 NormalTS 		: NORMALTS;
    float3 NormalWS         : NORMALWS;
    float2 LightMapUV       : LIGHTMAPUV;
};

struct PSInput
{
    float4 PositionSS 		: SV_Position;
    float3 NormalTS 		: NORMALTS;
    float3 NormalWS         : NORMALWS;
    float2 LightMapUV       : LIGHTMAPUV;
};

//=================================================================================================
// Vertex shader
//=================================================================================================
VSOutput VS(in float3 SpherePosition : POSITION, in uint InstanceID : SV_InstanceID)
{
    VSOutput output;

    // Get the sample point for this sphere
    BakePoint bakePoint = BakePoints[InstanceID];

    // Transform the sphere the orientation and position of the sample point
    float3 bitangent = normalize(cross(bakePoint.Normal, bakePoint.Tangent));
    bitangent *= sign(dot(bitangent, bakePoint.Bitangent));
    float4x4 transform = float4x4(float4(bakePoint.Tangent, 0.0f),
                                  float4(bitangent, 0.0f),
                                  float4(bakePoint.Normal, 0.0f),
                                  float4(bakePoint.Position, 1.0f));

    float size = min(bakePoint.Size.x, bakePoint.Size.y) * 0.3f;
    float3 positionWS = mul(float4(SpherePosition * size, 1.0f), transform).xyz;
    output.PositionCS = mul(float4(positionWS, 1.0f), ViewProjection);
    output.NormalTS = SpherePosition;
    output.NormalWS = mul(output.NormalTS, float3x3(bakePoint.Tangent, bitangent, bakePoint.Normal));
    output.LightMapUV = (bakePoint.TexelPos + 0.5f) / LightMapResolution;

    return output;
}

float3 EvalSGs(in float2 lightMapUV, in uint numSGs, in float3 dir)
{
    float3 output = 0.0f;

    [unroll]
    for(uint i = 0; i < numSGs; ++i)
    {
        SG sg;
        sg.Amplitude = BakedLightingMap.SampleLevel(LinearSampler, float3(lightMapUV, i), 0.0f).xyz;
        sg.Axis = SGDirections[i].xyz;
        sg.Sharpness = SGSharpness;

        output += EvaluateSG(sg, dir);
    }

    return output;
}

//=================================================================================================
// Pixel shader
//=================================================================================================
float4 PS(in PSInput input) : SV_Target0
{
    float3 output = 0.0f;

    float3 normalTS = normalize(input.NormalTS);
    float3 normalWS = normalize(input.NormalWS);
    float2 uv = input.LightMapUV;
    float3 normalSHSG = WorldSpaceBake ? normalWS : normalTS;

    if(BakeMode == BakeModes_Diffuse)
    {
        output = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 0.0f), 0.0f).xyz;
    }
    else if(BakeMode == BakeModes_HL2)
    {
     const float3 BasisDirs[3] =
        {
            float3(-1.0f / sqrt(6.0f), -1.0f / sqrt(2.0f), 1.0f / sqrt(3.0f)),
            float3(-1.0f / sqrt(6.0f), 1.0f / sqrt(2.0f), 1.0f / sqrt(3.0f)),
            float3(sqrt(2.0f / 3.0f), 0.0f, 1.0f / sqrt(3.0f)),
        };

        [unroll]
        for(uint i = 0; i < 3; ++i)
        {
            float3 lightMap = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, i), 0.0f).xyz;;
            output += saturate(dot(normalTS, BasisDirs[i])) * lightMap * InvPi;
        }
    }
	else if (BakeMode == BakeModes_Directional)
	{
        float3 lightMapColor = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 0), 0.0f).xyz;
        float4 lightmapDirection = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 1), 0.0f).xyzw;

        float rebalancingCoefficient = max(lightmapDirection.w, 0.0001);

        lightmapDirection = lightmapDirection * 2.0f - 1.0f;

        float4 tau = float4(normalize(normalWS), 1.0f) * 0.5f;
        float halfLambert = dot(tau, float4(lightmapDirection.xyz, 1.0f));

        output = lightMapColor * halfLambert / rebalancingCoefficient;
	}
	else if (BakeMode == BakeModes_DirectionalRGB)
	{
        float3 lightMapColor = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 0), 0.0f).xyz;
        float4 lightmapDirectionR = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 1), 0.0f).xyzw;
        float4 lightmapDirectionG = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 2), 0.0f).xyzw;
        float4 lightmapDirectionB = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, 3), 0.0f).xyzw;

        float3 rebalancingCoefficient = float3(max(lightmapDirectionR.w, 0.0001), max(lightmapDirectionG.w, 0.0001), max(lightmapDirectionB.w, 0.0001));

        lightmapDirectionR = lightmapDirectionR * 2.0f - 1.0f;
        lightmapDirectionG = lightmapDirectionG * 2.0f - 1.0f;
        lightmapDirectionB = lightmapDirectionB * 2.0f - 1.0f;

        float4 tau = float4(normalize(normalWS), 1.0f) * 0.5f;
        float3 halfLambert = float3(dot(tau, float4(lightmapDirectionR.xyz, 1.0f)),
            dot(tau, float4(lightmapDirectionG.xyz, 1.0f)),
            dot(tau, float4(lightmapDirectionB.xyz, 1.0f)));

        output = lightMapColor * halfLambert / rebalancingCoefficient;
	}
    else if(BakeMode == BakeModes_SH4)
    {
        SH4Color shRadiance;

        [unroll]
        for(uint i = 0; i < 4; ++i)
            shRadiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, i), 0.0f).xyz;

        output = EvalSH4(normalSHSG, shRadiance);
    }
    else if(BakeMode == BakeModes_SH9)
    {
        SH9Color shRadiance;

        [unroll]
        for(uint i = 0; i < 9; ++i)
            shRadiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, i), 0.0f).xyz;

        output = EvalSH9(normalSHSG, shRadiance);
    }
    else if(BakeMode == BakeModes_H4)
    {
        H4Color hbIrradiance;

        [unroll]
        for(uint i = 0; i < 4; ++i)
            hbIrradiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, i), 0.0f).xyz;

        output = EvalH4(normalTS, hbIrradiance) * InvPi;
    }
    else if(BakeMode == BakeModes_H6)
    {
        H6Color hbIrradiance;

        [unroll]
        for(uint i = 0; i < 6; ++i)
            hbIrradiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(uv, i), 0.0f).xyz;

        output = EvalH6(normalTS, hbIrradiance) * InvPi;
    }
    else if(BakeMode == BakeModes_SG5)
    {
        output = EvalSGs(uv, 5, normalSHSG);
    }
    else if(BakeMode == BakeModes_SG6)
    {
        output = EvalSGs(uv, 6, normalSHSG);
    }
    else if(BakeMode == BakeModes_SG9)
    {
        output = EvalSGs(uv, 9, normalSHSG);
    }
    else if(BakeMode == BakeModes_SG12)
    {
        output = EvalSGs(uv, 12, normalSHSG);
    }

    return float4(output, 1.0f);
}