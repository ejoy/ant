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

//#define DEPTH_LINEAR

#ifdef DEPTH_LINEAR
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
#ifdef DEPTH_LINEAR
	// when use multi sampler case, no need to check border
	vec2 tc = clamp(_shadowCoord.xy, 0.0, 1.0);
	float receiver = (_shadowCoord.z-_bias);
	float occluder = unpackRgbaToFloat(texture2D(_sampler, tc));
	return step(receiver, occluder);
#else
	vec4 coord = _shadowCoord;
	coord.z = max(0.0, coord.z - _bias);
	return shadow2DProj(_sampler, coord);
#endif
}

int select_cascade(float distanceVS)
{
	if (distanceVS < u_csm_split_distances[0])
		return 0;
		
	if (distanceVS < u_csm_split_distances[1])
		return 1;
		
	if (distanceVS < u_csm_split_distances[2])
		return 2;
		
	if (distanceVS < u_csm_split_distances[3])
		return 3;
	
	return 0;
}

vec4 get_color_coverage(int cascadeidx)
{
	float coverage = 0.8;
	mat4 color_coverages = mat4(
		coverage, 0.0, 0.0, 1.0,
		0.0, coverage, 0.0, 1.0,
		0.0, 0.0, coverage, 1.0,
		coverage, coverage, 0.0, 1.0);

	return color_coverages[cascadeidx];
}

vec4 calc_shadow_coord(float distanceVS, vec4 posWS)
{
	vec4 shadowcoord = vec4_splat(0.0);
	//TODO: NEED optimize! pass 'offset' and 'scale' to replace calculating pos projection in light space
	for (int ii = 3; ii >= 0; --ii){
		mat4 m = u_csm_matrix[ii];
		vec4 v = mul(m, posWS);
		vec4 t = v / v.w;
		float fidx = float(ii);
		if (0.25 * fidx <= t.x && t.x <= 0.25 * (fidx+1) &&
			0.0 < t.y && t.y < 1.0 && 0.0 <= t.z && t.z <= 1.0){
			shadowcoord = v;
		}
	}

	return shadowcoord;
}



#ifdef SHADOW_COVERAGE_DEBUG
static const vec4 g_colors[4] = {
	vec4(1.0, 0.0, 0.0, 1.0),
	vec4(0.0, 1.0, 0.0, 1.0),
	vec4(0.0, 0.0, 1.0, 1.0),
	vec4(0.0, 1.0, 1.0, 1.0)
};
#endif //SHADOW_COVERAGE_DEBUG

vec3 calc_shadow_color(float visibility, vec3 scenecolor)
{
	vec3 shadow_scenecolor = mix(u_shadow_color, scenecolor, visibility);
#ifdef SHADOW_COVERAGE_DEBUG
	shadow_scenecolor *= g_colors[cidx];
#endif //SHADOW_COVERAGE_DEBUG

	return shadow_scenecolor;
}

vec3 shadow_visibility(float distanceVS, vec4 posWS, vec3 scenecolor)
{
	vec4 shadowcoord = calc_shadow_coord(distanceVS, posWS);
	float visibility = saturate(hardShadow(s_shadowmap, shadowcoord, u_shadowmap_bias));
	return calc_shadow_color(visibility, scenecolor);
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
	return calc_shadow_color(visibility, scenecolor);
}

#endif //__SHADER_SHADOW_SH__