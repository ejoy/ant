//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include <Constants.hlsl>

//=================================================================================================
// Constant buffers
//=================================================================================================

cbuffer VSConstants : register (b0)
{
    float4x4 View;
    float4x4 Projection;
    float3 Bias;
}


cbuffer PSConstants : register (b0)
{
    float3 SunDirection;
    bool EnableSun;
    float3 SkyColor;
    float3 SunColor;
    float CosSunAngularRadius;
    float Scale;
}

//=================================================================================================
// Samplers
//=================================================================================================

TextureCube  EnvironmentMap : register(t0);
SamplerState LinearSampler : register(s0);


//=================================================================================================
// Input/Output structs
//=================================================================================================

struct VSInput
{
    float3 PositionOS : POSITION;
};

struct VSOutput
{
    float4 PositionCS   : SV_Position;
    float3 TexCoord     : TEXCOORD;
};


//=================================================================================================
// Vertex Shader
//=================================================================================================
VSOutput SkyboxVS(in VSInput input)
{
    VSOutput output;

    // Rotate into view-space, centered on the camera
    float3 positionVS = mul(input.PositionOS.xyz, (float3x3)View);

    // Transform to clip-space
    output.PositionCS = mul(float4(positionVS, 1.0f), Projection);

    // Make a texture coordinate
    output.TexCoord = input.PositionOS;

    return output;
}

//-------------------------------------------------------------------------------------------------
// Common pixel shader functionality
//-------------------------------------------------------------------------------------------------
float4 PSCommon(in VSOutput input, in float3 baseColor) : SV_Target
{
    float3 color = baseColor;

    // Draw a circle for the sun
    float3 dir = normalize(input.TexCoord);
    if(EnableSun)
    {
        float cosSunAngle = dot(dir, SunDirection);
        if(cosSunAngle >= CosSunAngularRadius)
            color = SunColor;
    }

    color *= Scale;
    color = clamp(color, 0.0f, FP16Max);

    return float4(color, 1.0f);
}

//=================================================================================================
// Environment Map Pixel Shader
//=================================================================================================
float4 SkyboxPS(in VSOutput input) : SV_Target
{
    // Sample the environment map
    float3 envMapClr = EnvironmentMap.Sample(LinearSampler, normalize(input.TexCoord)).rgb;
    return PSCommon(input, envMapClr);
}

//=================================================================================================
// Simple Sky Pixel Shader
//=================================================================================================
float4 SimpleSkyPS(in VSOutput input) : SV_Target
{
    return PSCommon(input, SkyColor);
}
