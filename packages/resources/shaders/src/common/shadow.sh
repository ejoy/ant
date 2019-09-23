/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"

uniform mat4 u_csm_matrix[4];
uniform vec4 u_csm_split_distances;
uniform vec4 u_shadow_param1;
uniform vec4 u_shadow_param2;
#define u_shadowmap_bias		u_shadow_param1.x
#define u_normaloffset 			u_shadow_param1.y
#define u_shadowmap_texelsize	u_shadow_param1.z
#define u_shadow_color			u_shadow_param2.xyz

//#define SM_LINEAR

#ifdef SM_LINEAR
#define SHADOW_SAMPLER2D	SAMPLER2D
#define shadow_sampler_type sampler2D 
#else
#define SHADOW_SAMPLER2D	SAMPLER2DSHADOW
#define shadow_sampler_type sampler2DShadow
#endif

SHADOW_SAMPLER2D(s_shadowmap, 7);

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
#ifdef SM_LINEAR
	// when use multi sampler case, no need to check border
	vec2 tc = clamp(_shadowCoord.xy, 0.0, 1.0);
	float receiver = (_shadowCoord.z-_bias);
	float occluder = texture2D(_sampler, tc).r;
	return step(receiver, occluder);
#else
	vec4 coord = _shadowCoord;
	coord.z -= _bias;
	return bgfxShadow2DProj(_sampler, coord);
#endif
}