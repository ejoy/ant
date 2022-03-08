/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

 #ifndef __SHADER_SHADOW_SH__
 #define __SHADER_SHADOW_SH__

#include "common.sh"

//csm
uniform mat4 u_csm_matrix[4];
uniform vec4 u_csm_split_distances;
uniform vec4 u_shadow_param1;
uniform vec4 u_shadow_param2;
#define u_shadowmap_bias		u_shadow_param1.x
#define u_normaloffset 			u_shadow_param1.y
#define u_shadowmap_texelsize	u_shadow_param1.z
#define u_shadow_color			u_shadow_param2.rgb

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
//#define PACK_RGBA8
//#define LINEAR_SHADOW
#ifdef LINEAR_SHADOW
#define SHADOW_SAMPLER2D	SAMPLER2D
#define shadow_sampler_type sampler2D 
#else
#define SHADOW_SAMPLER2D	SAMPLER2DSHADOW
#define shadow_sampler_type sampler2DShadow
#endif

#ifdef ENABLE_SHADOW
SHADOW_SAMPLER2D(s_shadowmap, 8);
SHADOW_SAMPLER2D(s_omni_shadowmap, 9);
#endif //ENABLE_SHADOW

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
	vec4 _shadowCoord, float _bias)
{
	// vec2 texCoord = _shadowCoord.xy/_shadowCoord.w;

	// bool outside = any(greaterThan(texCoord, vec2_splat(1.0)))
	// 			|| any(lessThan   (texCoord, vec2_splat(0.0)))
	// 			 ;

	// if (outside)
	// {
	// 	return 1.0;
	// }

	// float receiver = (_shadowCoord.z-_bias)/_shadowCoord.w;
	// float occluder = unpackRgbaToFloat(texture2D(_sampler, texCoord) );

	// float visibility = step(receiver, occluder);
	// return visibility;

	// NOTE: below code is same as this

#ifdef LINEAR_SHADOW
	vec2 texCoord = _shadowCoord.xy/_shadowCoord.w;
	float receiver = (_shadowCoord.z-_bias)/_shadowCoord.w;
	float occluder = texture2D(_sampler, texCoord).x;
	float visibility = step(receiver, occluder);
	return visibility;
#else //
	vec4 coord = _shadowCoord;
	coord.z -= _bias;
	return shadow2DProj(_sampler, coord);
#endif //LINEAR_SHADOW
}

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
	bool selection0 = all(lessThan(coords[0], vec2(0.249, 0.999))) && all(greaterThan(coords[0], vec2(0.001, 0.001)));
	bool selection1 = all(lessThan(coords[1], vec2(0.499, 0.999))) && all(greaterThan(coords[1], vec2(0.249, 0.001)));
	bool selection2 = all(lessThan(coords[2], vec2(0.749, 0.999))) && all(greaterThan(coords[2], vec2(0.499, 0.001)));
	bool selection3 = all(lessThan(coords[3], vec2(0.999, 0.999))) && all(greaterThan(coords[3], vec2(0.749, 0.001)));
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

vec3 shadow_visibility(float distanceVS, vec4 posWS, vec3 scenecolor)
{
	vec4 shadowcoord = vec4_splat(0.0);
#ifdef USE_VIEW_SPACE_DISTANCE
	int cascadeidx = select_cascade(distanceVS);
	if (cascadeidx < 0)
		return scenecolor;	// not in shadow
	shadowcoord = mul(u_csm_matrix[cascadeidx], posWS);
#else //!USE_VIEW_SPACE_DISTANCE
	int cascadeidx = calc_shadow_coord(posWS, shadowcoord);
	if (cascadeidx < 0)
		return scenecolor;	// not in shadow
#endif //USE_VIEW_SPACE_DISTANCE

	float visibility = hardShadow(s_shadowmap, shadowcoord, u_shadowmap_bias);
	vec3 finalcolor = mix(u_shadow_color, scenecolor, visibility);

#ifdef SHADOW_COVERAGE_DEBUG
	finalcolor *= g_colors[cascadeidx];
#endif //SHADOW_COVERAGE_DEBUG

	return finalcolor;
}

vec4 calc_omni_shadow_coord(vec4 posWS)
{
	vec4 selection = vec4(
		dot(u_tetra_normal_Green.xyz,  posWS.xyz),
		dot(u_tetra_normal_Yellow.xyz, posWS.xyz),
		dot(u_tetra_normal_Blue.xyz,   posWS.xyz),
		dot(u_tetra_normal_Red.xyz,    posWS.xyz));

	float face = max(max(selection.x, selection.y), max(selection.z, selection.w));
	for (int ii=0; ii<4; ++ii)
		if (face == selection[ii])
			return mul(u_omni_matrix[ii], posWS);

	return vec4_splat(0.0);
}

vec3 omni_shadow_visibility(vec4 posWS, vec3 scenecolor)
{
	vec4 shadowcoord = calc_omni_shadow_coord(posWS);
	float visibility = hardShadow(s_omni_shadowmap, shadowcoord, u_shadowmap_bias);
	return mix(u_shadow_color, scenecolor, visibility);
}

#endif //__SHADER_SHADOW_SH__