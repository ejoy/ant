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
#include <SH.hlsl>
#include <Sampling.hlsl>
#include "EVSM.hlsl"
#include "AppSettings.hlsl"
#include "SG.hlsl"

//=================================================================================================
// Constants
//=================================================================================================
static const uint NumCascades = 4;

//=================================================================================================
// Constant buffers
//=================================================================================================
cbuffer VSConstants : register(b0)
{
    float4x4 World;
	float4x4 View;
    float4x4 WorldViewProjection;
    float4x4 PrevWorldViewProjection;
}

cbuffer PSConstants : register(b0)
{
    float3 SunDirectionWS;
    float CosSunAngularRadius;
    float3 SunIlluminance;
    float SinSunAngularRadius;
    float3 CameraPosWS;
	float4x4 ShadowMatrix;
	float4 CascadeSplits;
    float4 CascadeOffsets[NumCascades];
    float4 CascadeScales[NumCascades];
    float OffsetScale;
    float PositiveExponent;
    float NegativeExponent;
    float LightBleedingReduction;
    float2 RTSize;
    float2 JitterOffset;
    float4 SGDirections[MaxSGCount];
    float SGSharpness;
}

//=================================================================================================
// Resources
//=================================================================================================
Texture2D<float4> AlbedoMap : register(t0);
Texture2D<float2> NormalMap : register(t1);
Texture2D<float> RoughnessMap : register(t2);
Texture2D<float> MetallicMap : register(t3);
Texture2DArray SunShadowMap : register(t4);
Texture2DArray<float4> BakedLightingMap : register(t5);
TextureCube<float> AreaLightShadowMap : register(t6);
Texture3D<float4> SHSpecularLookupA : register(t7);
Texture3D<float2> SHSpecularLookupB : register(t8);
Texture2D<float2> EnvSpecularLookup : register(t9);

SamplerState AnisoSampler : register(s0);
SamplerState EVSMSampler : register(s1);
SamplerState LinearSampler : register(s2);
SamplerComparisonState PCFSampler : register(s3);

//=================================================================================================
// Input/Output structs
//=================================================================================================
struct VSInput
{
    float3 PositionOS 		    : POSITION;
    float3 NormalOS 		    : NORMAL;
    float2 TexCoord 		    : TEXCOORD0;
    float2 LightMapUV           : TEXCOORD1;
	float3 TangentOS 		    : TANGENT;
	float3 BitangentOS		    : BITANGENT;
};

struct VSOutput
{
    float4 PositionCS 		    : SV_Position;

    float3 NormalWS 		    : NORMALWS;
    float3 PositionWS           : POSITIONWS;
    float DepthVS               : DEPTHVS;
	float3 TangentWS 		    : TANGENTWS;
	float3 BitangentWS 		    : BITANGENTWS;
	float2 TexCoord 		    : TEXCOORD;
    float2 LightMapUV           : LIGHTMAPUV;
    float3 PrevPosition         : PREVPOSITION;
};

struct PSInput
{
    float4 PositionSS 		    : SV_Position;

    float3 NormalWS 		    : NORMALWS;
    float3 PositionWS           : POSITIONWS;
    float DepthVS               : DEPTHVS;
    float3 TangentWS 		    : TANGENTWS;
	float3 BitangentWS 		    : BITANGENTWS;
    float2 TexCoord 		    : TEXCOORD;
    float2 LightMapUV           : LIGHTMAPUV;
    float3 PrevPosition         : PREVPOSITION;
};

struct PSOutput
{
    float4 Lighting             : SV_Target0;
    float2 Velocity             : SV_Target1;
};

//=================================================================================================
// Vertex Shader
//=================================================================================================
VSOutput VS(in VSInput input, in uint VertexID : SV_VertexID)
{
    VSOutput output;

    float3 positionOS = input.PositionOS;

    // Calc the world-space position
    output.PositionWS = mul(float4(positionOS, 1.0f), World).xyz;

    // Calc the clip-space position
    output.PositionCS = mul(float4(positionOS, 1.0f), WorldViewProjection);
    output.DepthVS = output.PositionCS.w;


	// Rotate the normal into world space
    output.NormalWS = normalize(mul(input.NormalOS, (float3x3)World));

	// Rotate the rest of the tangent frame into world space
	output.TangentWS = normalize(mul(input.TangentOS, (float3x3)World));
	output.BitangentWS = normalize(mul(input.BitangentOS, (float3x3)World));

    // Pass along the texture coordinates
    output.TexCoord = input.TexCoord;
    output.LightMapUV = input.LightMapUV;

    output.PrevPosition = mul(float4(input.PositionOS, 1.0f), PrevWorldViewProjection).xyw;

    return output;
}

//-------------------------------------------------------------------------------------------------
// Samples the EVSM shadow map
//-------------------------------------------------------------------------------------------------
float SampleShadowMapEVSM(in float3 shadowPos, in float3 shadowPosDX,
                          in float3 shadowPosDY, uint cascadeIdx)
{
    float2 exponents = GetEVSMExponents(PositiveExponent, NegativeExponent,
                                        CascadeScales[cascadeIdx].xyz);
    float2 warpedDepth = WarpDepth(shadowPos.z, exponents);

    float4 occluder = SunShadowMap.SampleGrad(EVSMSampler, float3(shadowPos.xy, cascadeIdx),
                                            shadowPosDX.xy, shadowPosDY.xy);

    // Derivative of warping at depth
    float2 depthScale = 0.0001f * exponents * warpedDepth;
    float2 minVariance = depthScale * depthScale;

    float posContrib = ChebyshevUpperBound(occluder.xz, warpedDepth.x, minVariance.x, LightBleedingReduction);
    float negContrib = ChebyshevUpperBound(occluder.yw, warpedDepth.y, minVariance.y, LightBleedingReduction);
    float shadowContrib = posContrib;
    shadowContrib = min(shadowContrib, negContrib);

    return shadowContrib;
}

//-------------------------------------------------------------------------------------------------
// Samples the appropriate shadow map cascade
//-------------------------------------------------------------------------------------------------
float3 SampleShadowCascade(in float3 shadowPosition, in float3 shadowPosDX,
                           in float3 shadowPosDY, in uint cascadeIdx)
{
    shadowPosition += CascadeOffsets[cascadeIdx].xyz;
    shadowPosition *= CascadeScales[cascadeIdx].xyz;

    shadowPosDX *= CascadeScales[cascadeIdx].xyz;
    shadowPosDY *= CascadeScales[cascadeIdx].xyz;

    float3 cascadeColor = 1.0f;

    float shadow = SampleShadowMapEVSM(shadowPosition, shadowPosDX, shadowPosDY, cascadeIdx);

    return shadow * cascadeColor;
}

//--------------------------------------------------------------------------------------
// Computes the sun visibility term by performing the shadow test
//--------------------------------------------------------------------------------------
float3 SunShadowVisibility(in float3 positionWS, in float depthVS)
{
	float3 shadowVisibility = 1.0f;
	uint cascadeIdx = 0;

    // Project into shadow space
    float3 samplePos = positionWS;
	float3 shadowPosition = mul(float4(samplePos, 1.0f), ShadowMatrix).xyz;
    float3 shadowPosDX = ddx(shadowPosition);
    float3 shadowPosDY = ddy(shadowPosition);

	// Figure out which cascade to sample from
	[unroll]
	for(uint i = 0; i < NumCascades - 1; ++i)
	{
		[flatten]
		if(depthVS > CascadeSplits[i])
			cascadeIdx = i + 1;
	}

	shadowVisibility = SampleShadowCascade(shadowPosition, shadowPosDX, shadowPosDY,
                                           cascadeIdx);

	return shadowVisibility;
}

//-------------------------------------------------------------------------------------------------
// Computes the area light shadow visibility term
//-------------------------------------------------------------------------------------------------
float AreaLightShadowVisibility(in float3 positionWS)
{
    float3 shadowPos = positionWS - float3(AreaLightX, AreaLightY, AreaLightZ);
    float3 shadowDistance = length(shadowPos);
    float3 shadowDir = normalize(shadowPos);

    // Doing the max of the components tells us 2 things: which cubemap face we're going to use,
    // and also what the projected distance is onto the major axis for that face.
    float projectedDistance = max(max(abs(shadowPos.x), abs(shadowPos.y)), abs(shadowPos.z));

    // Compute the project depth value that matches what would be stored in the depth buffer
    // for the current cube map face. Note that we use a reversed infinite projection.
    float nearClip = AreaLightSize;
    float a = 0.0f;
    float b = nearClip;
    float z = projectedDistance * a + b;
    float dbDistance = z / projectedDistance;

    return AreaLightShadowMap.SampleCmpLevelZero(PCFSampler, shadowDir, dbDistance + AreaLightShadowBias);
}

//-------------------------------------------------------------------------------------------------
// Calculates the lighting result for an analytical light source
//-------------------------------------------------------------------------------------------------
float3 CalcLighting(in float3 normal, in float3 lightDir, in float3 lightColor,
					in float3 diffuseAlbedo, in float3 specularAlbedo, in float roughness,
					in float3 view, inout float3 irradiance)
{
    float3 lighting = diffuseAlbedo * (1.0f / 3.14159f);

    const float nDotL = saturate(dot(normal, lightDir));
    if(nDotL > 0.0f)
    {
        const float nDotV = saturate(dot(normal, view));
        float3 h = normalize(view + lightDir);

        float3 fresnel = Fresnel(specularAlbedo, h, lightDir);

        float specular = GGX_Specular(roughness, normal, h, view, lightDir);
        lighting += specular * fresnel;
    }

    irradiance += nDotL * lightColor;
    return lighting * nDotL * lightColor;
}

// ------------------------------------------------------------------------------------------------
// Computes the irradiance for an SG light source using the selected approximation
// ------------------------------------------------------------------------------------------------
float3 SGIrradiance(in SG lightingLobe, in float3 normal)
{
    if(SGDiffuseMode == SGDiffuseModes_Punctual)
        return SGIrradiancePunctual(lightingLobe, normal);
    else if(SGDiffuseMode == SGDiffuseModes_Fitted)
        return SGIrradianceFitted(lightingLobe, normal);
    else
        return SGIrradianceInnerProduct(lightingLobe, normal);
}

// ------------------------------------------------------------------------------------------------
// Computes the specular contribution from an SG light source
// ------------------------------------------------------------------------------------------------
float3 SpecularTermSG(in SG light, in float3 normal, in float roughness,
                      in float3 view, in float3 specAlbedo)
{
    if(SGSpecularMode == SGSpecularModes_Punctual)
    {
        float3 irradiance;
        return CalcLighting(normal, light.Axis, ApproximateSGIntegral(light), 0.0f, specAlbedo, roughness, view, irradiance);
    }
    else if(SGSpecularMode == SGSpecularModes_SGWarp)
        return SpecularTermSGWarp(light, normal, roughness, view, specAlbedo);
    else
        return SpecularTermASGWarp(light, normal, roughness, view, specAlbedo);
}

// ------------------------------------------------------------------------------------------------
// Determine the exit radiance towards the eye from the SG's stored in the lightmap
// ------------------------------------------------------------------------------------------------
void ComputeSGContribution(in Texture2DArray<float4> bakedLightingMap, in float2 lightMapUV, in float3 normal,
                          in float3 specularAlbedo, in float roughness, in float3 view, in uint numSGs,
                          out float3 irradiance, out float3 specular)
{
    irradiance = 0.0f;
    specular = 0.0f;

    for(uint i = 0; i < numSGs; ++i)
    {
        SG sg;
        sg.Amplitude = bakedLightingMap.SampleLevel(LinearSampler, float3(lightMapUV, i), 0.0f).xyz;
        sg.Axis = SGDirections[i].xyz;
        sg.Sharpness = SGSharpness;

        irradiance += SGIrradiance(sg, normal);
        specular += SpecularTermSG(sg, normal, roughness, view, specularAlbedo);
    }
}

// ------------------------------------------------------------------------------------------------
// Computes the specular reflection from radiance encoded as a set of SH coefficients by
// convolving the radiance with another set of SH coefficients representing the current
// specular BRDF slice
// ------------------------------------------------------------------------------------------------
float3 ConvolutionSHSpecular(in float3 view, in float3 normal, in float3 specularAlbedo,
                             in float sqrtRoughness, in SH9Color shRadiance)
{
    // Make a local coordinate frame in tangent space or world space, with the x-axis
    // aligned with the view direction and the z-axis aligned with the normal
    float3 zBasis = normal;
    float3 yBasis = normalize(cross(zBasis, view));
    float3 xBasis = normalize(cross(yBasis, zBasis));
    float3x3 localFrame = float3x3(xBasis, yBasis, zBasis);
    float viewAngle = saturate(dot(normal, view));

    // Look up coefficients from the SH lookup texture to make the SH BRDF
    SH9Color shBrdf = (SH9Color)0.0f;

    [unroll]
    for(uint i = 0; i < 3; ++i)
    {
        float4 t0 = SHSpecularLookupA.SampleLevel(LinearSampler, float3(viewAngle, sqrtRoughness, specularAlbedo[i]), 0.0f);
        float2 t1 = SHSpecularLookupB.SampleLevel(LinearSampler, float3(viewAngle, sqrtRoughness, specularAlbedo[i]), 0.0f);
        shBrdf.c[0][i] = t0.x;
        shBrdf.c[2][i] = t0.y;
        shBrdf.c[3][i] = t0.z;
        shBrdf.c[6][i] = t0.w;
        shBrdf.c[7][i] = t1.x;
        shBrdf.c[8][i] = t1.y;
    }

    // Transform the SH BRDF to tangent space/world space
    shBrdf = RotateSH9(shBrdf, localFrame);

    // Convolve the BRDF slice with the environment radiance
    return SHDotProduct(shBrdf, shRadiance);
}

// ------------------------------------------------------------------------------------------------
// Computes approximated specular from radiance encoded as a set of SH coefficients by
// approximating a directional light in the "dominant" direction.
// From "Precomputed Global Illumination in Frostbite"
// https://www.ea.com/frostbite/news/precomputed-global-illumination-in-frostbite
// ------------------------------------------------------------------------------------------------
float3 FrostbiteSHSpecular(in float3 view, in float3 normal, in float3 specularAlbedo,
                           in float sqrtRoughness, in SH4Color shRadiance)
{
    float3 avgL1 = float3(-dot(shRadiance.c[3] / shRadiance.c[0], 0.333f),
                          -dot(shRadiance.c[1] / shRadiance.c[0], 0.333f),
                           dot(shRadiance.c[2] / shRadiance.c[0], 0.333f));
    avgL1 *= 0.5f;
    float avgL1len = length(avgL1);
    float3 specDir = avgL1 / avgL1len;

    float3 specLightColor = EvalSH4(specDir, shRadiance) * Pi;

    sqrtRoughness = saturate(sqrtRoughness * 1.0f / sqrt(avgL1len));
    float roughness = sqrtRoughness * sqrtRoughness;

    float3 irradiance;
    return CalcLighting(normal, specDir, specLightColor, 0.0f, specularAlbedo, roughness, view, irradiance);
}

// ------------------------------------------------------------------------------------------------
// A very rough SH specular approximation that converts the SH-projected radiance into 3 point
// lights oriented about the vertex normal
// ------------------------------------------------------------------------------------------------
float3 PunctualSHSpecular(in float3 view, in float3 normal, in float3x3 tangentFrame,
                          in float3 specularAlbedo, in float sqrtRoughness, in SH9Color shRadiance)
{
    const float3 lightDirs[] =
    {
        float3(-1.0f / sqrt(6.0f), -1.0f / sqrt(2.0f), 1.0f / sqrt(3.0f)),
        float3(-1.0f / sqrt(6.0f), 1.0f / sqrt(2.0f), 1.0f / sqrt(3.0f)),
        float3(sqrt(2.0f / 3.0f), 0.0f, 1.0f / sqrt(3.0f)),
    };

    float3 result = 0.0f;
    for(uint i = 0; i < 3; ++i)
    {
        const float3 lightDir = mul(lightDirs[i], tangentFrame);
        const float3 lightColor = EvalSH9(lightDir, shRadiance) * Pi;

        float3 irradiance;
        result += CalcLighting(normal, lightDir, lightColor, 0.0f, specularAlbedo,
                               sqrtRoughness * sqrtRoughness, view, irradiance);
    }

    return result / 3.0f;
}

float Square(in float x)
{
    return x * x;
}

// ------------------------------------------------------------------------------------------------
// Computes approximated specular from radiance encoded as a set of SH coefficients by
// treating the SH radiance as a pre-filtered environment map
// ------------------------------------------------------------------------------------------------
float3 PrefilteredSHSpecular(in float3 view, in float3 normal, in float3x3 tangentFrame,
                             in float3 specularAlbedo, in float sqrtRoughness, in SH9Color shRadiance)
{
    const float3 reflectDir = reflect(-view, normal);

    const float roughness = sqrtRoughness * sqrtRoughness;

    // Pre-filter the SH radiance with the GGX NDF using a fitted approximation
    const float l1Scale = 1.66711256633276f / (1.65715038133932f + roughness);
    const float l2Scale = 1.56127990596116f / (0.96989757593282f + roughness) - 0.599972342361123f;

    SH9Color filteredSHRadiance = shRadiance;
    filteredSHRadiance.c[1] *= l1Scale;
    filteredSHRadiance.c[2] *= l1Scale;
    filteredSHRadiance.c[3] *= l1Scale;
    filteredSHRadiance.c[4] *= l2Scale;
    filteredSHRadiance.c[5] *= l2Scale;
    filteredSHRadiance.c[6] *= l2Scale;
    filteredSHRadiance.c[7] *= l2Scale;
    filteredSHRadiance.c[8] *= l2Scale;

    float3 lookupDir = normalize(lerp(reflectDir, normal, saturate(roughness - 0.25f)));

    float3 specLightColor = max(EvalSH9(lookupDir, filteredSHRadiance), 0.0f);

    const float nDotV = saturate(dot(normal, view));
    const float2 AB = EnvSpecularLookup.SampleLevel(LinearSampler, float2(nDotV, sqrtRoughness), 0.0f);
    float3 envBRDF = specularAlbedo * AB.x + AB.y;

    // Testing a fitted polynomial approximation of the environment BRDF
    if(0)
    {
        const float nDotV2 = nDotV * nDotV;
        const float sqrtRoughness3 = roughness * sqrtRoughness;
        const float delta = 0.991086418474895f + 0.412367709802119f * sqrtRoughness * nDotV2 - 0.363848256078895f * roughness - 0.758634385642633f* nDotV * roughness;
        float B = 0.0306613448029984f * sqrtRoughness + 0.0238299731830387f / (0.0272458171384516f + sqrtRoughness3 + nDotV2) - 0.0454747751719356f;

        B = saturate(B);

        const float A = saturate(delta - B);
        envBRDF = specularAlbedo * A + B;
    }

    // Validation code for testing different specular components
    /*const bool TestGGXSampling = true;
    const bool TestFullGGX = true;

    if(TestGGXSampling)
    {
        const uint SqrtNumSamples = 8;
        const uint NumSamples = SqrtNumSamples * SqrtNumSamples;

        float3 sum = 0.0f;
        float weightSum = 0.00001f;

        for(uint sIdx = 0; sIdx < NumSamples; ++sIdx)
        {
            const float2 randFloats = SampleCMJ2D(sIdx, SqrtNumSamples, SqrtNumSamples, 0);

            float3 m = SampleGGXMicrofacet(roughness, randFloats.x, randFloats.y);
            float3 h = normalize(mul(m, tangentFrame));
            float3 l = normalize(2.0f * dot(h, view) * h - view);

            float nDotL = saturate(dot(normal, l));
            if(nDotL > 0)
            {
                if(TestFullGGX)
                {
                    float pdf = SampleDirectionGGX_PDF(normal, h, view, roughness);
                    float3 sampleWeight = GGX_Specular(roughness, normal, h, view, l) * nDotL / pdf;
                    sampleWeight *= Fresnel(specularAlbedo, h, l);
                    sum += max(EvalSH9(l, shRadiance), 0.0f) * sampleWeight;
                }
                else
                {
                    sum += max(EvalSH9(l, shRadiance), 0.0f) * nDotL;
                    weightSum += nDotL;
                }
            }
        }

        if(TestFullGGX)
        {
            weightSum = NumSamples;
            envBRDF = 1.0f;
        }

        specLightColor = sum / weightSum;
    }*/

    return envBRDF * specLightColor;
}

//=================================================================================================
// Pixel Shader
//=================================================================================================
PSOutput PS(in PSInput input)
{
	const float3 vtxNormal = normalize(input.NormalWS);
    const float3 positionWS = input.PositionWS;

    const float3 viewWS = normalize(CameraPosWS - positionWS);

    float3 normalWS = vtxNormal;

    const float2 uv = input.TexCoord;

	float3 normalTS = float3(0, 0, 1);
	float3 tangentWS = normalize(input.TangentWS);
	float3 bitangentWS = normalize(input.BitangentWS);
	float3x3 tangentToWorld = float3x3(tangentWS, bitangentWS, normalWS);

    if(EnableNormalMaps)
    {
        // Sample the normal map, and convert the normal to world space
        normalTS.xy = NormalMap.Sample(AnisoSampler, uv).xy * 2.0f - 1.0f;
        normalTS.z = sqrt(1.0f - saturate(normalTS.x * normalTS.x + normalTS.y * normalTS.y));
        normalTS = lerp(float3(0, 0, 1), normalTS, NormalMapIntensity);
        normalWS = normalize(mul(normalTS, tangentToWorld));
    }

    const float3 viewTS = mul(viewWS, transpose(tangentToWorld));

    const float3 normalSHSG = WorldSpaceBake ? normalWS : normalTS;
    const float3 viewSHSG = WorldSpaceBake ? viewWS : viewTS;
    const float3x3 tangentFrameSHSG = WorldSpaceBake ? tangentToWorld : float3x3(float3(1, 0, 0), float3(0, 1, 0), float3(0, 0, 1));

    // Gather material parameters
    float3 albedoMap = 1.0f;

    if(EnableAlbedoMaps)
        albedoMap = AlbedoMap.Sample(AnisoSampler, uv).xyz;

    const float metallic = saturate(MetallicMap.Sample(AnisoSampler, uv) + MetallicOffset);
    const float3 diffuseAlbedo = lerp(albedoMap.xyz, 0.0f, metallic) * DiffuseAlbedoScale * EnableDiffuse;
    const float3 specularAlbedo = lerp(0.03f, albedoMap.xyz, metallic) * EnableSpecular;

    float sqrtRoughness = RoughnessMap.Sample(AnisoSampler, uv);
    sqrtRoughness *= RoughnessScale;
    if(RoughnessOverride >= 0.01f)
        sqrtRoughness = RoughnessOverride;

    sqrtRoughness = saturate(sqrtRoughness);
    float roughness = sqrtRoughness * sqrtRoughness;

    float depthVS = input.DepthVS;

    // Add in the primary directional light
    float3 lighting = 0.0f;
    float3 irradiance = 0.0f;

    if(EnableDirectLighting && EnableSun && !BakeDirectSunLight)
    {
        float3 sunIrradiance = 0.0f;
        float3 sunShadowVisibility = SunShadowVisibility(positionWS, depthVS);
        float3 sunDirection = SunDirectionWS;
        if(SunAreaLightApproximation)
        {
            float3 D = SunDirectionWS;
            float3 R = reflect(-viewWS, normalWS);
            float r = SinSunAngularRadius;
            float d = CosSunAngularRadius;
            float3 DDotR = dot(D, R);
            float3 S = R - DDotR * D;
            sunDirection = DDotR < d ? normalize(d * D + normalize(S) * r) : R;
        }
        lighting += CalcLighting(normalWS, sunDirection, SunIlluminance, diffuseAlbedo, specularAlbedo,
                                 roughness, viewWS, sunIrradiance) * sunShadowVisibility;
        irradiance += sunIrradiance * sunShadowVisibility;
    }

    if(EnableDirectLighting && EnableAreaLight && BakeDirectAreaLight == false)
    {
        float3 areaLightPos = float3(AreaLightX, AreaLightY, AreaLightZ);
        float3 areaLightDir = normalize(areaLightPos - positionWS);
        float areaLightDist = length(areaLightPos - positionWS);
        SG lightLobe = MakeSphereSG(areaLightDir, AreaLightSize, AreaLightColor * FP16Scale, areaLightDist);
        float3 sgIrradiance = SGIrradiance(lightLobe, normalWS);

        float areaLightVisibility = 1.0f;
        if(EnableAreaLightShadows)
            areaLightVisibility = AreaLightShadowVisibility(positionWS);

        lighting += sgIrradiance * (diffuseAlbedo / Pi) * areaLightVisibility;
        lighting += SpecularTermSG(lightLobe, normalWS, roughness, viewWS, specularAlbedo) * areaLightVisibility;
        irradiance += sgIrradiance * areaLightVisibility;
    }

	// Add in the indirect
    if(EnableIndirectLighting || ViewIndirectDiffuse || ViewIndirectSpecular)
    {
        float3 indirectIrradiance = 0.0f;
        float3 indirectSpecular = 0.0f;

        if(BakeMode == BakeModes_Diffuse)
        {
            indirectIrradiance = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 0.0f), 0.0f).xyz * Pi;
        }
        else if(BakeMode == BakeModes_HL2)
        {
            const float3 BasisDirs[3] =
            {
                float3(-1.0f / sqrt(6.0f), -1.0f / sqrt(2.0f), 1.0f / sqrt(3.0f)),
                float3(-1.0f / sqrt(6.0f), 1.0f / sqrt(2.0f), 1.0f / sqrt(3.0f)),
                float3(sqrt(2.0f / 3.0f), 0.0f, 1.0f / sqrt(3.0f)),
            };

            float weightSum = 0.0f;

            [unroll]
            for(uint i = 0; i < 3; ++i)
            {
                float3 lightMap = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, i), 0.0f).xyz;
                indirectIrradiance += saturate(dot(normalTS, BasisDirs[i])) * lightMap;
            }
        }
		else if (BakeMode == BakeModes_Directional)
		{
			float3 lightMapColor = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 0), 0.0f).xyz * Pi;
			float4 lightmapDirection = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 1), 0.0f).xyzw;

			float rebalancingCoefficient = max(lightmapDirection.w, 0.0001);

			lightmapDirection = lightmapDirection * 2.0f - 1.0f;

			float4 tau = float4(normalize(normalWS), 1.0f) * 0.5f;
			float halfLambert = dot(tau, float4(lightmapDirection.xyz, 1.0f));

			indirectIrradiance = lightMapColor * halfLambert / rebalancingCoefficient;
		}
        else if(BakeMode == BakeModes_DirectionalRGB)
        {
            float3 lightMapColor = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 0), 0.0f).xyz * Pi;
            float4 lightmapDirectionR = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 1), 0.0f).xyzw;
            float4 lightmapDirectionG = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 2), 0.0f).xyzw;
            float4 lightmapDirectionB = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, 3), 0.0f).xyzw;

            float3 rebalancingCoefficient = float3(max(lightmapDirectionR.w, 0.0001), max(lightmapDirectionG.w, 0.0001), max(lightmapDirectionB.w, 0.0001));

            lightmapDirectionR = lightmapDirectionR * 2.0f - 1.0f;
            lightmapDirectionG = lightmapDirectionG * 2.0f - 1.0f;
            lightmapDirectionB = lightmapDirectionB * 2.0f - 1.0f;

            float4 tau = float4(normalize(normalWS), 1.0f) * 0.5f;
            float3 halfLambert = float3(dot(tau, float4(lightmapDirectionR.xyz, 1.0f)),
                dot(tau, float4(lightmapDirectionG.xyz, 1.0f)),
                dot(tau, float4(lightmapDirectionB.xyz, 1.0f)));

            indirectIrradiance = lightMapColor * halfLambert / rebalancingCoefficient;
        }
        else if(BakeMode == BakeModes_SH4)
        {
            SH4Color shRadiance;

            [unroll]
            for(uint i = 0; i < 4; ++i)
                shRadiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, i), 0.0f).xyz;

            if(SH4DiffuseMode == SH4DiffuseModes_Geomerics)
                indirectIrradiance = EvalSH4IrradianceGeomerics(normalSHSG, shRadiance);
            else
                indirectIrradiance = EvalSH4Irradiance(normalSHSG, shRadiance);

            if(SHSpecularMode == SHSpecularModes_DominantDirection)
                indirectSpecular = FrostbiteSHSpecular(viewSHSG, normalSHSG, specularAlbedo, sqrtRoughness, shRadiance);
            else if(SHSpecularMode == SHSpecularModes_Punctual)
                indirectSpecular = PunctualSHSpecular(viewSHSG, normalSHSG, tangentFrameSHSG, specularAlbedo, sqrtRoughness, ConvertToSH9(shRadiance));
            else if(SHSpecularMode == SHSpecularModes_Prefiltered)
                indirectSpecular = PrefilteredSHSpecular(viewSHSG, normalSHSG, tangentFrameSHSG, specularAlbedo, sqrtRoughness, ConvertToSH9(shRadiance));
            else
                indirectSpecular = ConvolutionSHSpecular(viewSHSG, normalSHSG, specularAlbedo, sqrtRoughness, ConvertToSH9(shRadiance));
        }
        else if(BakeMode == BakeModes_SH9)
        {
            SH9Color shRadiance;

            [unroll]
            for(uint i = 0; i < 9; ++i)
                shRadiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, i), 0.0f).xyz;

            indirectIrradiance = EvalSH9Irradiance(normalSHSG, shRadiance);

            if(SHSpecularMode == SHSpecularModes_DominantDirection)
                indirectSpecular = FrostbiteSHSpecular(viewSHSG, normalSHSG, specularAlbedo, sqrtRoughness, ConvertToSH4(shRadiance));
            else if(SHSpecularMode == SHSpecularModes_Punctual)
                indirectSpecular = PunctualSHSpecular(viewSHSG, normalSHSG, tangentFrameSHSG, specularAlbedo, sqrtRoughness, shRadiance);
            else if(SHSpecularMode == SHSpecularModes_Prefiltered)
                indirectSpecular = PrefilteredSHSpecular(viewSHSG, normalSHSG, tangentFrameSHSG, specularAlbedo, sqrtRoughness, shRadiance);
            else
                indirectSpecular = ConvolutionSHSpecular(viewSHSG, normalSHSG, specularAlbedo, sqrtRoughness, shRadiance);
        }
        else if(BakeMode == BakeModes_H4)
        {
            H4Color hbIrradiance;

            [unroll]
            for(uint i = 0; i < 4; ++i)
                hbIrradiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, i), 0.0f).xyz;

            indirectIrradiance = EvalH4(normalTS, hbIrradiance);
        }
        else if(BakeMode == BakeModes_H6)
        {
            H6Color hbIrradiance;

            [unroll]
            for(uint i = 0; i < 6; ++i)
                hbIrradiance.c[i] = BakedLightingMap.SampleLevel(LinearSampler, float3(input.LightMapUV, i), 0.0f).xyz;

            indirectIrradiance = EvalH6(normalTS, hbIrradiance);
        }
        else if(BakeMode == BakeModes_SG5)
        {
            ComputeSGContribution(BakedLightingMap, input.LightMapUV, normalSHSG, specularAlbedo, roughness,
                                  viewSHSG, 5, indirectIrradiance, indirectSpecular);
        }
        else if(BakeMode == BakeModes_SG6)
        {
            ComputeSGContribution(BakedLightingMap, input.LightMapUV, normalSHSG, specularAlbedo, roughness,
                                  viewSHSG, 6, indirectIrradiance, indirectSpecular);
        }
        else if(BakeMode == BakeModes_SG9)
        {
            ComputeSGContribution(BakedLightingMap, input.LightMapUV, normalSHSG, specularAlbedo, roughness,
                                  viewSHSG, 9, indirectIrradiance, indirectSpecular);
        }
        else if(BakeMode == BakeModes_SG12)
        {
            ComputeSGContribution(BakedLightingMap, input.LightMapUV, normalSHSG, specularAlbedo, roughness,
                                  viewSHSG, 12, indirectIrradiance, indirectSpecular);
        }

        if(EnableIndirectDiffuse)
        {
            irradiance += indirectIrradiance;
            lighting += indirectIrradiance * (diffuseAlbedo / Pi);
        }

        if(EnableIndirectSpecular)
            lighting += indirectSpecular;

        if(ViewIndirectDiffuse)
            lighting = indirectIrradiance / Pi;

        if(ViewIndirectSpecular)
            lighting = indirectSpecular;
    }

    float illuminance = dot(irradiance, float3(0.2126f, 0.7152f, 0.0722f));

    PSOutput output;
    output.Lighting =  clamp(float4(lighting, illuminance), 0.0f, FP16Max);

    float2 prevPositionSS = (input.PrevPosition.xy / input.PrevPosition.z) * float2(0.5f, -0.5f) + 0.5f;
    prevPositionSS *= RTSize;
    output.Velocity = input.PositionSS.xy - prevPositionSS;
    output.Velocity -= JitterOffset;
    output.Velocity /= RTSize;

    return output;
}
