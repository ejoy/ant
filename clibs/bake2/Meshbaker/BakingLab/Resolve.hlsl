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
#include "Exposure.hlsl"

//=================================================================================================
// Constants
//=================================================================================================
#ifndef MSAASamples_
    #define MSAASamples_ 1
#endif

#ifndef FilterType_
    #define FilterType_ 0
#endif

#define MSAA_ (MSAASamples_ > 1)

// These are the sub-sample locations for the 2x, 4x, and 8x standard multisample patterns.
// See the MSDN documentation for the D3D11_STANDARD_MULTISAMPLE_QUALITY_LEVELS enumeration.
#if MSAASamples_ == 8
    static const float2 SubSampleOffsets[8] = {
        float2( 0.0625f, -0.1875f),
        float2(-0.0625f,  0.1875f),
        float2( 0.3125f,  0.0625f),
        float2(-0.1875f, -0.3125f),
        float2(-0.3125f,  0.3125f),
        float2(-0.4375f, -0.0625f),
        float2( 0.1875f,  0.4375f),
        float2( 0.4375f, -0.4375f),
    };
#elif MSAASamples_ == 4
    static const float2 SubSampleOffsets[4] = {
        float2(-0.125f, -0.375f),
        float2( 0.375f, -0.125f),
        float2(-0.375f,  0.125f),
        float2( 0.125f,  0.375f),
    };
#elif MSAASamples_ == 2
    static const float2 SubSampleOffsets[2] = {
        float2( 0.25f,  0.25f),
        float2(-0.25f, -0.25f),
    };
#else
    static const float2 SubSampleOffsets[1] = {
        float2(0.0f, 0.0f),
    };
#endif

#if MSAA_
    #define MSAALoad_(tex, addr, subSampleIdx) tex.Load(uint2(addr), subSampleIdx)
#else
    #define MSAALoad_(tex, addr, subSampleIdx) tex[uint2(addr)]
#endif

//=================================================================================================
// Resources
//=================================================================================================
#if MSAA_
    Texture2DMS<float4> InputTexture : register(t0);
    Texture2DMS<float2> VelocityTexture : register(t1);
#else
    Texture2D<float4> InputTexture : register(t0);
    Texture2D<float2> VelocityTexture : register(t1);
#endif

Texture2D<float4> PrevFrameTexture : register(t2);
Texture2D<float> AvgLuminanceTexture : register(t3);

SamplerState LinearSampler : register(s0);

cbuffer ResolveConstants : register(b0)
{
    int SampleRadius;
    bool EnableTemporalAA;
    float2 TextureSize;
}

float FilterBox(in float x)
{
    return 1.0f;
}

static float FilterTriangle(in float x)
{
    return saturate(1.0f - x);
}

static float FilterGaussian(in float x)
{
    const float sigma = GaussianSigma;
    const float g = 1.0f / sqrt(2.0f * 3.14159f * sigma * sigma);
    return (g * exp(-(x * x) / (2 * sigma * sigma)));
}

 float FilterCubic(in float x, in float B, in float C)
{
    // Rescale from [-2, 2] range to [-FilterWidth, FilterWidth]
    x *= 2.0f;

    float y = 0.0f;
    float x2 = x * x;
    float x3 = x * x * x;
    if(x < 1)
        y = (12 - 9 * B - 6 * C) * x3 + (-18 + 12 * B + 6 * C) * x2 + (6 - 2 * B);
    else if (x <= 2)
        y = (-B - 6 * C) * x3 + (6 * B + 30 * C) * x2 + (-12 * B - 48 * C) * x + (8 * B + 24 * C);

    return y / 6.0f;
}

float FilterBlackmanHarris(in float x)
{
    x = 1.0f - x;

    const float a0 = 0.35875f;
    const float a1 = 0.48829f;
    const float a2 = 0.14128f;
    const float a3 = 0.01168f;
    return saturate(a0 - a1 * cos(Pi * x) + a2 * cos(2 * Pi * x) - a3 * cos(3 * Pi * x));
}

float FilterSmoothstep(in float x)
{
    return 1.0f - smoothstep(0.0f, 1.0f, x);
}

float Filter(in float x)
{
    if(FilterType == FilterTypes_Box)
        return FilterBox(x);
    else if(FilterType == FilterTypes_Triangle)
        return FilterTriangle(x);
    else if(FilterType == FilterTypes_Gaussian)
        return FilterGaussian(x);
    else if(FilterType == FilterTypes_BlackmanHarris)
        return FilterBlackmanHarris(x);
    else if(FilterType == FilterTypes_Smoothstep)
        return FilterSmoothstep(x);
    else if(FilterType == FilterTypes_BSpline)
        return FilterCubic(x, 1.0, 0.0f);
    else
        return 1.0f;
}

float4 ResolveVS(in uint VertexID : SV_VertexID) : SV_Position
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

float Luminance(in float3 clr)
{
    return dot(clr, float3(0.2126f, 0.7152f, 0.0722f));
}

float4 ResolvePS(in float4 Position : SV_Position) : SV_Target0
{
    const bool InverseLuminanceFiltering = true;
    const bool UseExposureFiltering = true;
    const float ExposureFilterOffset = 2.0f;

    const float avgLuminance = AvgLuminanceTexture[uint2(0, 0)];
    const float exposure = exp2(Log2Exposure(avgLuminance) + ExposureFilterOffset);

    float2 pixelPos = Position.xy;
    float3 sum = 0.0f;
    float totalWeight = 0.0f;

    float3 clrMin = 99999999.0f;
    float3 clrMax = -99999999.0f;

    #if MSAA_
        const int SampleRadius_ = SampleRadius;
    #else
        const int SampleRadius_ = 1;
    #endif

    for(int y = -SampleRadius_; y <= SampleRadius_; ++y)
    {
        for(int x = -SampleRadius_; x <= SampleRadius_; ++x)
        {
            float2 sampleOffset = float2(x, y);
            float2 samplePos = pixelPos + sampleOffset;
            samplePos = clamp(samplePos, 0, TextureSize - 1.0f);

            [unroll]
            for(uint subSampleIdx = 0; subSampleIdx < MSAASamples_; ++subSampleIdx)
            {
                float2 subSampleOffset = SubSampleOffsets[subSampleIdx].xy;
                float sampleDist = length(sampleOffset + subSampleOffset) / (FilterSize / 2.0f);

                [branch]
                if(sampleDist <= 1.0f)
                {
                    float3 sample = MSAALoad_(InputTexture, samplePos, subSampleIdx).xyz;
                    sample = max(sample, 0.0f);

                    float weight = Filter(sampleDist);
                    clrMin = min(clrMin, sample);
                    clrMax = max(clrMax, sample);

                    float sampleLum = Luminance(sample);

                    if(UseExposureFiltering)
                        sampleLum *= exposure;

                    if(InverseLuminanceFiltering)
                        weight *= 1.0f / (1.0f + sampleLum);

                    sum += sample * weight;
                    totalWeight += weight;
                }
            }
        }
    }

    #if MSAA_
        float3 output = sum / max(totalWeight, 0.00001f);
    #else
        float3 output = InputTexture[uint2(pixelPos)].xyz;
    #endif

    output = max(output, 0.0f);

    if(EnableTemporalAA)
    {
        const float TemporalAABlendFactor = 0.9f;
        const bool UseTemporalColorWeighting = false;
        const bool ClampPrevColor = true;
        const float LowFreqWeight = 0.25f;
        const float HiFreqWeight = 0.85f;

        float3 currColor = output;

        float2 velocity = 0.0f;
        float greatestVelocity = -1.0f;
        for(int vy = -1; vy <= 1; ++vy)
        {
            for(int vx = -1; vx <= 1; ++vx)
            {
                [unroll]
                for(uint vsIdx = 0; vsIdx < MSAASamples_; ++vsIdx)
                {
                    float2 neighborVelocity = MSAALoad_(VelocityTexture, pixelPos + int2(vx, vy), vsIdx);
                    float neighborVelocityMag = dot(neighborVelocity, neighborVelocity);
                    if(dot(neighborVelocity, neighborVelocity) > greatestVelocity)
                    {
                        velocity = neighborVelocity;
                        greatestVelocity = neighborVelocityMag;
                    }
                }
            }
        }

        velocity *= TextureSize;

        float2 prevPixelPos = pixelPos - velocity;
        float2 prevUV = prevPixelPos / TextureSize;

        float3 prevColor = PrevFrameTexture.SampleLevel(LinearSampler, prevUV, 0.0f).xyz;

        if(ClampPrevColor)
            prevColor = clamp(prevColor, clrMin, clrMax);

        float3 weightA = saturate(1.0f - TemporalAABlendFactor);
        float3 weightB = saturate(TemporalAABlendFactor);

        if(UseTemporalColorWeighting)
        {
            float3 temporalWeight = saturate(abs(clrMax - clrMin) / currColor);
            weightB = saturate(lerp(LowFreqWeight, HiFreqWeight, temporalWeight));
            weightA = 1.0f - weightB;
        }

        if(InverseLuminanceFiltering)
        {
            float currLuminance = Luminance(currColor);
            float prevLuminance = Luminance(prevColor);
            if(UseExposureFiltering)
            {
                currLuminance *= exposure;
                prevLuminance *= exposure;
            }

            weightA *= 1.0f / (1.0f + currLuminance);
            weightB *= 1.0f / (1.0f + prevLuminance);
        }

        output = (currColor * weightA + prevColor * weightB) / (weightA + weightB);
    }

    #if MSAA_
        float illuminance = InputTexture.Load(uint2(pixelPos), 0).w;
    #else
        float illuminance = InputTexture[uint2(pixelPos)].w;
    #endif

    return float4(output, illuminance);
}