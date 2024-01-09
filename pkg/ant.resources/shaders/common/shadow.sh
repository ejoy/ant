/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

 #ifndef __SHADER_SHADOW_SH__
 #define __SHADER_SHADOW_SH__

#ifdef ENABLE_SHADOW

#include "common/common.sh"

//csm
uniform mat4 u_csm_matrix[4];
uniform vec4 u_csm_split_distances;
uniform vec4 u_shadow_param1;
uniform vec4 u_shadow_param2;

#define u_max_cascade_level		u_shadow_param1.x
#define u_minVariance 			u_shadow_param1.y
#define u_shadowmap_texelsize	u_shadow_param1.z
#define u_depthMultiplier 		u_shadow_param1.w

#define u_normal_offset 		u_shadow_param2.w

// omni
uniform mat4 u_omni_matrix[4];
uniform vec4 u_tetra_normal_Green;
uniform vec4 u_tetra_normal_Yellow;
uniform vec4 u_tetra_normal_Blue;
uniform vec4 u_tetra_normal_Red;

//TODO: we keep omni shadow with cluster shading, find the shadowmap in cluster index
uniform vec4 u_omni_param;
#define u_omni_count u_omni_param.x

#define USE_VIEW_SPACE_DISTANCE
//#define SHADOW_COVERAGE_DEBUG

#define SM_HARD 
//#define SM_PCF
//#define SM_ESM

#if defined(SM_HARD)
#define USE_SHADOW_COMPARE
#endif //

#ifdef USE_SHADOW_COMPARE
#define SHADOW_SAMPLER2D	SAMPLER2DSHADOW
#define shadow_sampler_type sampler2DShadow
#else
#define SHADOW_SAMPLER2D	SAMPLER2D
#define shadow_sampler_type sampler2D 
#endif

SHADOW_SAMPLER2D(s_shadowmap, 8);

bool is_texcoord_in_range(vec2 _texcoord, float minv, float maxv)
{
	return 	all(greaterThan(_texcoord, vec2_splat(minv))) && 
			all(lessThan   (_texcoord, vec2_splat(maxv)));
}

bool is_proj_texcoord_in_range(vec4 texcoord, float minv, float maxv)
{
	return is_texcoord_in_range(texcoord.xy/texcoord.w, minv, maxv);
}


float hardShadow(
	shadow_sampler_type _sampler,
	vec4 _shadowCoord)
{
#ifdef USE_SHADOW_COMPARE
	vec4 coord = _shadowCoord;

	return shadow2DProj(_sampler, coord);
#else //!USE_SHADOW_COMPARE
	vec2 texCoord = _shadowCoord.xy/_shadowCoord.w;
	float receiver = (_shadowCoord.z)/_shadowCoord.w;
	float occluder = texture2D(_sampler, texCoord).x;
	float visibility = step(occluder, receiver);
	return visibility;
#endif //USE_SHADOW_COMPARE
}

#ifdef SM_PCF
float PCF(
	shadow_sampler_type _sampler,
	vec4 _shadowCoord,
	float _fTexelSize,
	float _fNativeTexelSizeInX)
{
	int m_iPCFBlurForLoopStart = -3;
	int m_iPCFBlurForLoopEnd = 4;
	float visibility = 0.0;
    for( int x = m_iPCFBlurForLoopStart; x < m_iPCFBlurForLoopEnd; ++x ) 
    {
        for( int y = m_iPCFBlurForLoopStart; y < m_iPCFBlurForLoopEnd; ++y ) 
        {
			vec2 texCoord = _shadowCoord.xy / _shadowCoord.w;
            float receiver = (_shadowCoord.z) / _shadowCoord.w;
			texCoord.x += x*_fNativeTexelSizeInX;
			texCoord.y += y*_fTexelSize;
			float occluder = texture2D(_sampler, texCoord).x;		
            visibility += step(occluder, receiver);
        }
    }
	return visibility / 49.0;	
}
#endif //SM_PCF

#ifdef SM_VSM
float VSM(
	shadow_sampler_type _sampler,
	vec4 _shadowCoord,
	float _depthMultiplier, float _minVariance) 
{
	vec2 texCoord = _shadowCoord.xy / _shadowCoord.w;
	bool outside = any(greaterThan(texCoord, vec2_splat(1.0)))
				|| any(lessThan   (texCoord, vec2_splat(0.0)))
				 ;

	if (outside)
	{
		return 1.0;
	}

	float receiver = (_shadowCoord.z) / _shadowCoord.w * _depthMultiplier;
	vec2  occluder = texture2D(_sampler, texCoord);
	float depth    = occluder.x * _depthMultiplier;
	float depthSq  = occluder.y * _depthMultiplier;
	if (receiver > depth)
	{
		return 1.0;
	}	
	float variance = max(depth * depth - depthSq, _minVariance);
	float d = depth - receiver;
	float visibility = variance / (variance + d * d);
	return visibility;
}
#endif //SM_VSM

#ifdef SM_ESM
float ESM(
	shadow_sampler_type _sampler,
	vec4 _shadowCoord,
	float _depthMultiplier) 
{
	vec2 texCoord = _shadowCoord.xy / _shadowCoord.w;
	bool outside = any(greaterThan(texCoord, vec2_splat(1.0)))
				|| any(lessThan   (texCoord, vec2_splat(0.0)))
				 ;

	if (outside)
	{
		return 1.0;
	}	
	float receiver = (_shadowCoord.z + 0.005) / _shadowCoord.w;

	float occluder = texture2D(_sampler, texCoord);	

	float visibility = clamp(exp(_depthMultiplier * (receiver - occluder) ), 0.0, 1.0);
	return visibility;
}
#endif //SM_ESM


int select_cascade(float distanceVS)
{
	vec4 v = step(vec4_splat(distanceVS), u_csm_split_distances);
	int idx = int(dot(v, vec4_splat(1.0)));
	int m[5] = {-1, 3, 2, 1, 0};
	return m[idx];
}

int calc_shadow_coord(vec4 posWS, out vec4 shadowcoord)
{
	// //TODO: NEED optimize! pass 'offset' and 'scale' to replace calculating pos projection in light space
	// for (int ii = 3; ii >= 0; --ii){
	// 	mat4 m = u_csm_matrix[ii];
	// 	vec4 v = mul(m, posWS);
	// 	vec4 t = v / v.w;
	// 	float fidx = float(ii);
	// 	if (0.25 * fidx <= t.x && t.x <= 0.25 * (fidx+1) &&
	// 		0.0 < t.y && t.y < 1.0 && 0.0 <= t.z && t.z <= 1.0){
	// 		shadowcoord = v;
	// 	}
	// }

	// return shadowcoord;

	vec4 coords[4] = {
		mul(u_csm_matrix[0], posWS),
		mul(u_csm_matrix[1], posWS),
		mul(u_csm_matrix[2], posWS),
		mul(u_csm_matrix[3], posWS),
	};

	// cascade shadow is store in [n*s, s] texture 2d
	bool selection0 = all(lessThan(coords[0].xy, vec2(0.249, 0.999))) && all(greaterThan(coords[0].xy, vec2(0.001, 0.001)));
	bool selection1 = all(lessThan(coords[1].xy, vec2(0.499, 0.999))) && all(greaterThan(coords[1].xy, vec2(0.249, 0.001)));
	bool selection2 = all(lessThan(coords[2].xy, vec2(0.749, 0.999))) && all(greaterThan(coords[2].xy, vec2(0.499, 0.001)));
	bool selection3 = all(lessThan(coords[3].xy, vec2(0.999, 0.999))) && all(greaterThan(coords[3].xy, vec2(0.749, 0.001)));
	int cascadeidx = -1;
	if (selection0){
		cascadeidx = 0;
	} else if (selection1){
		cascadeidx = 1;
	} else if (selection2){
		cascadeidx = 2;
	} else if (selection3){
		cascadeidx = 3;
	} else {
		return -1;
	}

	shadowcoord = coords[cascadeidx];
	return cascadeidx;
}

#ifdef SHADOW_COVERAGE_DEBUG
static const vec4 g_colors[4] = {
	vec4(1.0, 0.0, 0.0, 1.0),
	vec4(0.0, 1.0, 0.0, 1.0),
	vec4(0.0, 0.0, 1.0, 1.0),
	vec4(0.0, 1.0, 1.0, 1.0)
};
#endif //SHADOW_COVERAGE_DEBUG

float sample_visibility(vec4 shadowcoord)
{
#ifdef SM_HARD
	return hardShadow(s_shadowmap, shadowcoord);
#endif //SM_HARD

#ifdef SM_PCF
	float fNativeTexelSizeInX = u_shadowmap_texelsize / 8;
	float fNativeTexelSizeInY = u_shadowmap_texelsize / 4;
	return PCF(s_shadowmap, shadowcoord, fNativeTexelSizeInY, fNativeTexelSizeInX);
#endif //SM_PCF

#ifdef SM_ESM
	return ESM(s_shadowmap, shadowcoord, u_depthMultiplier);
#endif //SM_ESM

#ifdef SM_VSM
	return VSM(s_shadowmap, shadowcoord, 1, 0.012);
#endif //SM_VSM

	return 0.0;
}

float shadow_visibility(float distanceVS, vec4 posWS)
{
	vec4 shadowcoord = vec4_splat(0.0);
#ifdef USE_VIEW_SPACE_DISTANCE
	int cascadeidx = select_cascade(distanceVS);
	if (cascadeidx < 0 || cascadeidx > (int)u_max_cascade_level)
		return 0.0;	// not in shadow
	shadowcoord = mul(u_csm_matrix[cascadeidx], posWS);
#else //!USE_VIEW_SPACE_DISTANCE
	int cascadeidx = calc_shadow_coord(posWS, shadowcoord);
	if (cascadeidx < 0)
		return 0.0;	// not in shadow
#endif //USE_VIEW_SPACE_DISTANCE

	return sample_visibility(shadowcoord);
}
#endif //ENABLE_SHADOW
#endif //__SHADER_SHADOW_SH__