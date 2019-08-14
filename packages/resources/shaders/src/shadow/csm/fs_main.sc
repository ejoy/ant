/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"

uniform vec4 u_params0;
uniform vec4 u_params1;
uniform vec4 u_params2;
uniform vec4 u_color;

uniform vec4 u_materialKa;
uniform vec4 u_materialKd;
uniform vec4 u_materialKs;
uniform vec4 u_lightPosition;
uniform vec4 u_lightAmbientPower;
uniform vec4 u_lightDiffusePower;
uniform vec4 u_lightSpecularPower;
uniform vec4 u_lightSpotDirectionInner;
uniform vec4 u_lightAttenuationSpotOuter;
uniform vec4 u_smSamplingParams;
uniform vec4 u_csmFarDistances;

#if SM_OMNI
uniform vec4 u_tetraNormalGreen;
uniform vec4 u_tetraNormalYellow;
uniform vec4 u_tetraNormalBlue;
uniform vec4 u_tetraNormalRed;
#endif

SAMPLER2D(s_shadowMap0, 4);
SAMPLER2D(s_shadowMap1, 5);
SAMPLER2D(s_shadowMap2, 6);
SAMPLER2D(s_shadowMap3, 7);

struct Shader
{
	vec3 ambi;
	vec3 diff;
	vec3 spec;
};

Shader evalShader(float _diff, float _spec)
{
	Shader shader;

	shader.ambi = u_lightAmbientPower.xyz  * u_lightAmbientPower.w  * u_materialKa.xyz;
	shader.diff = u_lightDiffusePower.xyz  * u_lightDiffusePower.w  * u_materialKd.xyz * _diff;
	shader.spec = u_lightSpecularPower.xyz * u_lightSpecularPower.w * u_materialKs.xyz * _spec;

	return shader;
}

float computeVisibility(sampler2D _sampler
					  , vec4 _shadowCoord
					  , float _bias
					  , vec4 _samplingParams
					  , vec2 _texelSize
					  , float _depthMultiplier
					  , float _minVariance
					  , float _hardness
					  )
{
	float visibility;

#if SM_LINEAR
	vec4 shadowcoord = vec4(_shadowCoord.xy / _shadowCoord.w, _shadowCoord.z, 1.0);
#else
	vec4 shadowcoord = _shadowCoord;
#endif

#if SM_HARD
	visibility = hardShadow(_sampler, shadowcoord, _bias);
#elif SM_PCF
	visibility = PCF(_sampler, shadowcoord, _bias, _samplingParams, _texelSize);
#elif SM_VSM
	visibility = VSM(_sampler, shadowcoord, _bias, _depthMultiplier, _minVariance);
#elif SM_ESM
	visibility = ESM(_sampler, shadowcoord, _bias, _depthMultiplier * _hardness);
#endif

	return visibility;
}

#define u_ambientPass    u_params0.x
#define u_lightingPass   u_params0.y

#define u_shadowMapBias   u_params1.x
#define u_shadowMapParam0 u_params1.z
#define u_shadowMapParam1 u_params1.w

#define u_shadowMapShowCoverage u_params2.y
#define u_shadowMapTexelSize    u_params2.z

#define u_spotDirection   u_lightSpotDirectionInner.xyz
#define u_spotInner       u_lightSpotDirectionInner.w
#define u_lightAttnParams u_lightAttenuationSpotOuter.xyz
#define u_spotOuter       u_lightAttenuationSpotOuter.w

// Pcf
#define u_shadowMapPcfMode     u_shadowMapParam0
#define u_shadowMapNoiseAmount u_shadowMapParam1

// Vsm
#define u_shadowMapMinVariance     u_shadowMapParam0
#define u_shadowMapDepthMultiplier u_shadowMapParam1

// Esm
#define u_shadowMapHardness        u_shadowMapParam0
#define u_shadowMapDepthMultiplier u_shadowMapParam1

void main()
{
	vec3 colorCoverage;
	float visibility;

#if SM_CSM
	vec2 texelSize = vec2_splat(u_shadowMapTexelSize);

	vec2 texcoord1 = v_texcoord1.xy/v_texcoord1.w;
	vec2 texcoord2 = v_texcoord2.xy/v_texcoord2.w;
	vec2 texcoord3 = v_texcoord3.xy/v_texcoord3.w;
	vec2 texcoord4 = v_texcoord4.xy/v_texcoord4.w;

	bool selection0 = all(lessThan(texcoord1, vec2_splat(0.99))) && all(greaterThan(texcoord1, vec2_splat(0.01)));
	bool selection1 = all(lessThan(texcoord2, vec2_splat(0.99))) && all(greaterThan(texcoord2, vec2_splat(0.01)));
	bool selection2 = all(lessThan(texcoord3, vec2_splat(0.99))) && all(greaterThan(texcoord3, vec2_splat(0.01)));
	bool selection3 = all(lessThan(texcoord4, vec2_splat(0.99))) && all(greaterThan(texcoord4, vec2_splat(0.01)));

	if (selection0)
	{
		vec4 shadowcoord = v_texcoord1;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(-coverage, coverage, -coverage);
		visibility = computeVisibility(s_shadowMap0
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
	else if (selection1)
	{
		vec4 shadowcoord = v_texcoord2;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(coverage, coverage, -coverage);
		visibility = computeVisibility(s_shadowMap1
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize/2.0
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
	else if (selection2)
	{
		vec4 shadowcoord = v_texcoord3;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(-coverage, -coverage, coverage);
		visibility = computeVisibility(s_shadowMap2
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize/3.0
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
	else //selection3
	{
		vec4 shadowcoord = v_texcoord4;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(coverage, -coverage, -coverage);
		visibility = computeVisibility(s_shadowMap3
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize/4.0
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
#elif SM_OMNI
	vec2 texelSize = vec2_splat(u_shadowMapTexelSize/4.0);

	vec4 faceSelection;
	vec3 pos = v_position.xyz;
	faceSelection.x = dot(u_tetraNormalGreen.xyz,  pos);
	faceSelection.y = dot(u_tetraNormalYellow.xyz, pos);
	faceSelection.z = dot(u_tetraNormalBlue.xyz,   pos);
	faceSelection.w = dot(u_tetraNormalRed.xyz,    pos);

	vec4 shadowcoord;
	float faceMax = max(max(faceSelection.x, faceSelection.y), max(faceSelection.z, faceSelection.w));
	if (faceSelection.x == faceMax)
	{
		shadowcoord = v_texcoord1;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(-coverage, coverage, -coverage);
	}
	else if (faceSelection.y == faceMax)
	{
		shadowcoord = v_texcoord2;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(coverage, coverage, -coverage);
	}
	else if (faceSelection.z == faceMax)
	{
		shadowcoord = v_texcoord3;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(-coverage, -coverage, coverage);
	}
	else // (faceSelection.w == faceMax)
	{
		shadowcoord = v_texcoord4;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(coverage, -coverage, -coverage);
	}

	visibility = computeVisibility(s_shadowMap0
					, shadowcoord
					, u_shadowMapBias
					, u_smSamplingParams
					, texelSize
					, u_shadowMapDepthMultiplier
					, u_shadowMapMinVariance
					, u_shadowMapHardness
					);
#else
	vec2 texelSize = vec2_splat(u_shadowMapTexelSize);

	float coverage = texcoordInRange(v_shadowcoord.xy/v_shadowcoord.w) * 0.3;
	colorCoverage = vec3(coverage, -coverage, -coverage);

	visibility = computeVisibility(s_shadowMap0
					, v_shadowcoord
					, u_shadowMapBias
					, u_smSamplingParams
					, texelSize
					, u_shadowMapDepthMultiplier
					, u_shadowMapMinVariance
					, u_shadowMapHardness
					);
#endif

	vec3 v = v_view;
	vec3 vd = -normalize(v_view);
	vec3 n = v_normal;
	Light light = evalLight(v, u_lightPosition, u_spotDirection, u_spotInner, u_spotOuter, u_lightAttnParams);

	vec2 lc = lit(light.ld, n, vd, u_materialKs.w) * light.attn;
	Shader shader = evalShader(lc.x, lc.y);

	//Fog.
	vec3 fogColor = vec3_splat(0.0);
	float fogDensity = 0.0035;
	float LOG2 = 1.442695;
	float z = length(v);
	float fogFactor = clamp(1.0/exp2(fogDensity*fogDensity*z*z*LOG2), 0.0, 1.0);

	vec3 color = u_color.xyz;

	vec3 ambient = shader.ambi * color;
	vec3 brdf    = (shader.diff + shader.spec) * color * visibility;

	vec3 final = toGamma(abs(ambient + brdf)) + (colorCoverage * u_shadowMapShowCoverage);
	gl_FragColor.xyz = mix(fogColor, final, fogFactor);
	gl_FragColor.w = 1.0;
}
