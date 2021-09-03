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
#include "Exposure.hlsl"
#include "ACES.hlsl"

// == Utility functions ===========================================================================

// Approximates luminance from an RGB value
float CalcLuminance(float3 color)
{
    return dot(color, float3(0.2126f, 0.7152f, 0.0722f));
}

// Retrieves the log-average luminance from the texture
float GetAvgLuminance(Texture2D lumTex)
{
    return lumTex.Load(uint3(0, 0, 0)).x;
}

float3 LinearTosRGB(in float3 color)
{
    float3 x = color * 12.92f;
    float3 y = 1.055f * pow(saturate(color), 1.0f / 2.4f) - 0.055f;

    float3 clr = color;
    clr.r = color.r < 0.0031308f ? x.r : y.r;
    clr.g = color.g < 0.0031308f ? x.g : y.g;
    clr.b = color.b < 0.0031308f ? x.b : y.b;

    return clr;
}

float3 SRGBToLinear(in float3 color)
{
    float3 x = color / 12.92f;
    float3 y = pow(max((color + 0.055f) / 1.055f, 0.0f), 2.4f);

    float3 clr = color;
    clr.r = color.r <= 0.04045f ? x.r : y.r;
    clr.g = color.g <= 0.04045f ? x.g : y.g;
    clr.b = color.b <= 0.04045f ? x.b : y.b;

    return clr;
}

// Applies the filmic curve from John Hable's presentation
float3 ToneMapFilmicALU(in float3 color)
{
    color = max(0, color - 0.004f);
    color = (color * (6.2f * color + 0.5f)) / (color * (6.2f * color + 1.7f)+ 0.06f);
    return color;
}

float3 ToneMap_Hejl2015(in float3 hdr)
{
    float4 vh = float4(hdr, WhitePoint_Hejl);
    float4 va = (1.435f * vh) + 0.05;
    float4 vf = ((vh * va + 0.004f) / ((vh * (va + 0.55f) + 0.0491f))) - 0.0821f;
    return LinearTosRGB(vf.xyz / vf.www);
}

float3 HableFunction(in float3 x) {
    const float A = ShoulderStrength;
    const float B = LinearStrength;
    const float C = LinearAngle;
    const float D = ToeStrength;

    // Not exposed as settings
    const float E = 0.01f;
    const float F = 0.3f;

    return ((x * (A * x + C * B)+ D * E) / (x * (A * x + B) + D * F)) - E / F;
}

float3 ToneMap_Hable(in float3 color) {
    float3 numerator = HableFunction(color);
    float3 denominator = HableFunction(WhitePoint_Hable);

    return LinearTosRGB(numerator / denominator);
}

// Applies exposure and tone mapping to the specific color, and applies
// the threshold to the exposure value.
float3 ToneMap(in float3 color, in float avgLuminance, in float threshold, out float exposure)
{
    color = CalcExposedColor(color, avgLuminance, threshold, exposure);

    float3 output = 0;
    if(ToneMappingMode == ToneMappingModes_Linear)
        output = LinearTosRGB(color);
    else if(ToneMappingMode == ToneMappingModes_FilmStock)
        output = ToneMapFilmicALU(color);
    else if(ToneMappingMode == ToneMappingModes_ACES)
        output = LinearTosRGB(ACESFitted(color) * 1.8f);
    else if(ToneMappingMode == ToneMappingModes_Hejl2015)
        output = ToneMap_Hejl2015(color);
    else if(ToneMappingMode == ToneMappingModes_Hable)
        output = ToneMap_Hable(color);

    return output;
}

// Applies exposure and tone mapping to the input
float4 ToneMap(in PSInput input) : SV_Target0
{
    // Tone map the primary input
    float avgLuminance = GetAvgLuminance(InputTexture1);
    float3 color = InputTexture0.Sample(PointSampler, input.TexCoord).rgb;

    color += InputTexture2.Sample(LinearSampler, input.TexCoord).xyz * BloomMagnitude * exp2(BloomExposure);

    float exposure = 0;
    color = ToneMap(color, avgLuminance, 0, exposure);

    return float4(color, 1.0f);
}
