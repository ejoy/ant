//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include <PPIncludes.hlsl>
#include <Constants.hlsl>
#include "AppSettings.hlsl"

//=================================================================================================
// Constants
//=================================================================================================
cbuffer PPConstants : register(b1)
{
    float TimeDelta;
    bool EnableAdaptation;
    float DisplayWidth;
    float DisplayHeight;

    row_major float4x4 Projection;
};

//=================================================================================================
// Helper Functions
//=================================================================================================

// Calculates the gaussian blur weight for a given distance and sigmas
float CalcGaussianWeight(int sampleDist, float sigma)
{
    float g = 1.0f / sqrt(2.0f * 3.14159 * sigma * sigma);
    return (g * exp(-(sampleDist * sampleDist) / (2 * sigma * sigma)));
}

// Performs a gaussian blur in one direction
float4 Blur(in PSInput input, float2 texScale, float sigma, bool nrmlize)
{
    float4 color = 0;
    float weightSum = 0.0f;
    for(int i = -7; i < 7; i++)
    {
        float weight = CalcGaussianWeight(i, sigma);
        weightSum += weight;
        float2 texCoord = input.TexCoord;
        texCoord += (i / InputSize0) * texScale;
        float4 sample = InputTexture0.Sample(PointSampler, texCoord);
        color += sample * weight;
    }

    if(nrmlize)
        color /= weightSum;

    return color;
}

// ------------------------------------------------------------------------------------------------
// Samples a texture with B-spline (bicubic) filtering
// ------------------------------------------------------------------------------------------------
float4 SampleTextureBSpline(in Texture2D textureMap, in SamplerState linearSampler, in float2 uv) {
    float2 texSize;
    textureMap.GetDimensions(texSize.x, texSize.y);
    float2 invTexSize = 1.0f / texSize;

    float2 a = frac(uv * texSize - 0.5f);
    float2 a2 = a * a;
    float2 a3 = a2 * a;
    float2 w0 = (1.0f / 6.0f) * (-a3 + 3 * a2 - 3 * a + 1);
    float2 w1 = (1.0f / 6.0f) * (3 * a3 - 6 * a2 + 4);
    float2 w2 = (1.0f / 6.0f) * (-3 * a3 + 3 * a2 + 3 * a + 1);
    float2 w3 = (1.0f / 6.0f) * a3;
    float2 g0 = w0 + w1;
    float2 g1 = w2 + w3;
    float2 h0 = 1.0f - (w1 / (w0 + w1)) + a;
    float2 h1 = 1.0f - (w3 / (w2 + w3)) - a;

    float2 ex = float2(invTexSize.x, 0.0f);
    float2 ey = float2(0.0f, invTexSize.y);

    w0 = 0.5f;
    w1 = 0.5f;
    g0 = 0.5f;

    float2 uv10 = uv + h0.x * ex;
    float2 uv00 = uv - h1.x * ex;
    float2 uv11 = uv10 + h0.y * ey;
    float2 uv01 = uv00 + h0.y * ey;
    uv10 = uv10 - h1.y * ey;
    uv00 = uv00 - h1.y * ey;

    uv00 = uv + float2(-0.75f, -0.75f) * invTexSize;
    uv10 = uv + float2(0.75f, -0.75f) * invTexSize;
    uv01 = uv + float2(-0.75f, 0.75f) * invTexSize;
    uv11 = uv + float2(0.75f, 0.75f) * invTexSize;

    float4 sample00 = textureMap.SampleLevel(linearSampler, uv00, 0.0f);
    float4 sample10 = textureMap.SampleLevel(linearSampler, uv10, 0.0f);
    float4 sample01 = textureMap.SampleLevel(linearSampler, uv01, 0.0f);
    float4 sample11 = textureMap.SampleLevel(linearSampler, uv11, 0.0f);

    sample00 = lerp(sample00, sample01, g0.y);
    sample10 = lerp(sample10, sample11, g0.y);
    return lerp(sample00, sample10, g0.x);
}

// ================================================================================================
// Shader Entry Points
// ================================================================================================

Texture2D<float4> BloomInput : register(t0);

// Initial pass for bloom
float4 Bloom(in PSInput input) : SV_Target
{
    float4 reds = BloomInput.GatherRed(LinearSampler, input.TexCoord);
    float4 greens = BloomInput.GatherGreen(LinearSampler, input.TexCoord);
    float4 blues = BloomInput.GatherBlue(LinearSampler, input.TexCoord);

    float3 result = 0.0f;

    [unroll]
    for(uint i = 0; i < 4; ++i)
    {
        float3 color = float3(reds[i], greens[i], blues[i]);

        // Apply exposure offset
        /*float avgLuminance = GetAvgLuminance(InputTexture1);
        float exposure = 0;
        result += CalcExposedColor(color, avgLuminance, BloomExposure, exposure);*/

        result += color;
    }

    result /= 4.0f;

    return float4(result, 1.0f);
}

// Uses hw bilinear filtering for upscaling or downscaling
float4 Scale(in PSInput input) : SV_Target
{
    return InputTexture0.Sample(PointSampler, input.TexCoord);
}

// Horizontal gaussian blur
float4 BlurH(in PSInput input) : SV_Target
{
    return Blur(input, float2(1, 0), BloomBlurSigma, false);
}

// Vertical gaussian blur
float4 BlurV(in PSInput input) : SV_Target
{
    return Blur(input, float2(0, 1), BloomBlurSigma, false);
}

// Depth of field shaders

static const float MaxCOCSize = 21.0f;

Texture2D<float4> ColorMap : register(t0);

#if MSAA_
    Texture2DMS<float> DepthMap : register(t1);
#else
    Texture2D<float> DepthMap : register(t1);
#endif

struct NearFarOutput
{
    float4 Near : SV_Target0;
    float4 Far : SV_Target1;
};

float CoC(in float zw)
{
    float z = Projection._43 / (zw - Projection._33);

    // Compute CoC in meters
    float coc = -ApertureWidth * (FocalLength * (FocusDistance - z)) / (z * (FocusDistance - FocalLength));

    // Convert to pixels
    coc = (coc / FilmSize) * DisplayWidth;

    // Clamp to the max COC size
    coc = clamp(coc / MaxCOCSize, -1.0f, 1.0f);

    return coc;
}

// Calculates the CoC for a pixel and outputs it to the alpha channel
NearFarOutput CalculateCoC(in PSInput input)
{
    float3 color = ColorMap[uint2(input.PositionSS.xy)].xyz;
    #if MSAA_
        float zw = DepthMap.Load(uint2(input.PositionSS.xy), 0);
        float coc = CoC(zw);

        uint width, height, numSamples;
        DepthMap.GetDimensions(width, height, numSamples);

        for(uint i = 1; i < numSamples; ++i)
        {
            float sampleCoC = CoC(DepthMap.Load(uint2(input.PositionSS.xy), i));
            if(abs(sampleCoC) < coc)
                coc = sampleCoC;
        }
    #else
        float zw = DepthMap[uint2(input.PositionSS.xy)];
        float coc = CoC(zw);
    #endif

    NearFarOutput output;
    output.Near = float4(color, 1.0f) * max(-coc, 0.0f);
    output.Near.xyz = color;
    output.Far = float4(color, 1.0f) * max(coc, 0.0f);
    return output;
}

// Downscales to 1/2 res, and calculates CoC
NearFarOutput DOFDownscale(in PSInput input)
{
    float2 pixelPos = floor(input.PositionSS.xy) * 2.0f;
    NearFarOutput output;
    output.Near = 0.0f;
    output.Far = 0.0f;

    [unroll]
    for(uint y = 0; y < 2; ++y) {
        [unroll]
        for(uint x = 0; x < 2; ++x) {
            PSInput tapInput = input;
            tapInput.PositionSS.xy = pixelPos + float2(x, y);
            NearFarOutput tapOutput = CalculateCoC(tapInput);

            output.Near += tapOutput.Near;
            output.Far += tapOutput.Far;
        }
    }

    output.Near /= 4.0f;
    output.Far /= 4.0f;

    return output;
}

float DilateNearMask(in PSInput input) : SV_Target
{
    float2 inputPos = floor(input.PositionSS.xy);

    static const int SampleRadius = 2;
    static const int SampleDiameter = SampleRadius * 2 + 1;

    float output = InputTexture0[inputPos].x;

    [unroll]
    for(int y = -SampleRadius; y <= SampleRadius; ++y)
    {
        [unroll]
        for(int x = -SampleRadius; x <= SampleRadius; ++x)
        {
           output = max(output, InputTexture0[inputPos + float2(x, y)].x);
        }
    }

    return output;
}

// Horizontal gaussian blur
float NearMaskBlurH(in PSInput input) : SV_Target
{
    float center = InputTexture0[uint2(input.PositionSS.xy)].x * 0;
    return max(center, Blur(input, float2(1, 0), 2.0f, true).x);
}

// Vertical gaussian blur
float NearMaskBlurV(in PSInput input) : SV_Target
{
    float center = InputTexture0[uint2(input.PositionSS.xy)].x * 0;
    return max(center, Blur(input, float2(0, 1), 2.0f, true).x);
}

// Maps a value inside the square [0,1]x[0,1] to a value in a disk of radius 1 using concentric squares.
// This mapping preserves area, bi continuity, and minimizes deformation.
// Based off the algorithm "A Low Distortion Map Between Disk and Square" by Peter Shirley and
// Kenneth Chiu. Also includes polygon morphing modification from "CryEngine3 Graphics Gems"
// by Tiago Sousa
float2 SquareToConcentricDiskMapping(float x, float y, float numSides, float polygonAmount)
{
    float phi, r;

    // -- (a,b) is now on [-1,1]ˆ2
    float a = 2.0f * x - 1.0f;
    float b = 2.0f * y - 1.0f;

    if(a > -b)                      // region 1 or 2
    {
        if(a > b)                   // region 1, also |a| > |b|
        {
            r = a;
            phi = (Pi / 4.0f) * (b / a);
        }
        else                        // region 2, also |b| > |a|
        {
            r = b;
            phi = (Pi / 4.0f) * (2.0f - (a / b));
        }
    }
    else                            // region 3 or 4
    {
        if(a < b)                   // region 3, also |a| >= |b|, a != 0
        {
            r = -a;
            phi = (Pi / 4.0f) * (4.0f + (b / a));
        }
        else                        // region 4, |b| >= |a|, but a==0 and b==0 could occur.
        {
            r = -b;
            if(abs(b) > 0.0f)
                phi = (Pi / 4.0f) * (6.0f - (a / b));
            else
                phi = 0;
        }
    }

    const float N = numSides;
    float polyModifier = cos(Pi / N) / cos(phi - (Pi2 / N) * floor((N * phi + Pi) / Pi2));
    r *= lerp(1.0f, polyModifier, polygonAmount);

    float2 result;
    result.x = r * cos(phi);
    result.y = r * sin(phi);

    return result;
}

// Performs a gather-based DOF using single analytical kernel
NearFarOutput KernelGatherDOF(in PSInput input)
{
    const uint NumDOFSamples = 7;
    const uint NumSamples = NumDOFSamples * NumDOFSamples;
    float2 inputPos = input.PositionSS.xy;

    NearFarOutput output;
    output.Near = 0.0f;
    output.Far = 0.0f;

    const float ShapeCurve = 2.0f;
    const float ShapeCurveAmt = 0.0f;

    const float MaxKernelSize = MaxCOCSize * 0.5f;

    float farCoC = InputTexture1[inputPos].w;
    float kernelRadius = MaxKernelSize * farCoC;

    [branch]
    if(kernelRadius > 0.5f)
    {
        [unroll]
        for(uint i = 0; i < NumSamples; ++i)
        {
            float lensX = saturate((i % NumDOFSamples) / max(NumDOFSamples - 1.0f, 1.0f));
            float lensY = saturate((i / NumDOFSamples) / max(NumDOFSamples - 1.0f, 1.0f));
            float2 kernelOffset = SquareToConcentricDiskMapping(lensX, lensY, float(NumBlades), BokehPolygonAmount);
            float4 sample = InputTexture1.SampleLevel(LinearSampler, (inputPos + kernelOffset * kernelRadius) / InputSize0, 0.0f);
            float sampleCoC = sample.w;

            sample *= saturate(1.0f + (sampleCoC - farCoC));
            sample *= (1.0f - ShapeCurveAmt) + pow(max(length(kernelOffset), 0.01f), ShapeCurve) * ShapeCurveAmt;
            output.Far += sample;
        }

        output.Far /= NumSamples;
    }
    else
        output.Far = InputTexture1[inputPos];

    float nearCoC = InputTexture0[inputPos].w;
    float nearMask = SampleTextureBSpline(InputTexture2, LinearSampler, input.TexCoord).x;
    float4 nearMaskGather = InputTexture2.GatherRed(LinearSampler, input.TexCoord);
    nearMask = saturate(nearMask * 1.0f);
    nearCoC = max(nearCoC, nearMask);
    kernelRadius = MaxKernelSize * nearCoC;

    [branch]
    if(kernelRadius > 0.25f)
    {
        float weightSum = 0.00001f;

        [unroll]
        for(uint i = 0; i < NumSamples; ++i)
        {
            float lensX = saturate((i % NumDOFSamples) / max(NumDOFSamples - 1.0f, 1.0f));
            float lensY = saturate((i / NumDOFSamples) / max(NumDOFSamples - 1.0f, 1.0f));
            float2 kernelOffset = SquareToConcentricDiskMapping(lensX, lensY, float(NumBlades), BokehPolygonAmount);
            float4 sample = InputTexture0.SampleLevel(LinearSampler, (inputPos + kernelOffset * kernelRadius) / InputSize0, 0.0f);
            float sampleCoC = sample.w * MaxKernelSize;

            float sampleWeight = 1.0f;

            output.Near.xyz += sample.xyz * sampleWeight;

            float sampleDist = length(kernelOffset) * kernelRadius;

            float sampleAlpha = 1.0f;
            sampleAlpha *= saturate(sampleCoC * 1.0f);
            output.Near.w += sampleAlpha * sampleWeight;

            weightSum += sampleWeight;
        }

        output.Near.xyz /= weightSum;
        output.Near.w = saturate(output.Near.w  * (1.0f / NumSamples));
        output.Near.w = max(output.Near.w, InputTexture0[inputPos].w);
    }
    else
        output.Near = float4(InputTexture0[inputPos].xyz, 0.0f);

    return output;
}

// Performs a "flood-fill" to fill in the gaps between sparse samples
NearFarOutput FloodFillDOF(in PSInput input)
{
    float2 inputPos = floor(input.PositionSS.xy);

    NearFarOutput output;
    output.Near = 0.0f;
    output.Far = 0.0f;

    static const int SampleRadius = 1;
    static const int SampleDiameter = SampleRadius * 2 + 1;

    [unroll]
    for(int y = -SampleRadius; y <= SampleRadius; ++y)
    {
        [unroll]
        for(int x = -SampleRadius; x <= SampleRadius; ++x)
        {
           output.Near += InputTexture0[inputPos + float2(x, y)];
           output.Far += InputTexture1[inputPos + float2(x, y)];
        }
    }

    output.Near /= float(SampleDiameter * SampleDiameter);
    output.Far /= float(SampleDiameter * SampleDiameter);

    return output;
}

#if MSAA_
    Texture2DMS<float> UpscaleDepthMap : register(t4);
#else
    Texture2D<float> UpscaleDepthMap : register(t4);
#endif

// Composite the DOF output with the full-res original input
float4 DOFComposite(in PSInput input) : SV_Target0
{
    float3 originalSample = InputTexture2[uint2(input.PositionSS.xy)].xyz;

     #if MSAA_
        float zw = UpscaleDepthMap.Load(uint2(input.PositionSS.xy), 0);
        float coc = CoC(zw);

        uint width, height, numSamples;
        UpscaleDepthMap.GetDimensions(width, height, numSamples);

        for(uint i = 1; i < numSamples; ++i)
        {
            float sampleCoC = CoC(UpscaleDepthMap.Load(uint2(input.PositionSS.xy), i));
            if(abs(sampleCoC) < coc)
                coc = sampleCoC;
        }
    #else
        float zw = UpscaleDepthMap[uint2(input.PositionSS.xy)];
        float coc = CoC(zw);
    #endif

    float4 nearSample = InputTexture0.SampleLevel(LinearSampler, input.TexCoord, 0.0f);
    float3 near = originalSample;
    near = nearSample.xyz;

    float4 farSample = InputTexture1.SampleLevel(LinearSampler, input.TexCoord, 0.0f);
    float3 far = originalSample;
    if(farSample.w > 0.0f)
        far = farSample.xyz / farSample.w;

    float nearMask = InputTexture3.SampleLevel(LinearSampler, input.TexCoord, 0.0f).x;

    float farBlend = saturate(saturate(coc) * MaxCOCSize - 0.5f);
    float3 result = lerp(originalSample, far.xyz, smoothstep(0.0f, 1.0f, farBlend));

    float nearBlend = saturate(nearSample.w * 2.0f);
    result = lerp(result, near.xyz, smoothstep(0.0f, 1.0f, nearBlend));

    return float4(result, coc);
}