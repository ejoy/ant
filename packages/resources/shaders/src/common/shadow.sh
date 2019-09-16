/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"

uniform mat4 directional_viewproj[4];

uniform vec4 u_shadow_param1;
uniform vec4 u_shadow_param2;
#define u_shadowmap_bias		u_shadow_param1.x
#define u_normaloffset 			u_shadow_param1.y
#define u_shadowmap_texelsize	u_shadow_param1.z
#define u_shadow_color			u_shadow_param2.xyz

// need move these shadowmaps to single shadowmap
#ifdef SM_LINEAR
SAMPLER2D(s_shadowmap0, 4);
SAMPLER2D(s_shadowmap1, 5);
SAMPLER2D(s_shadowmap2, 6);
SAMPLER2D(s_shadowmap3, 7);
#else
SAMPLER2DSHADOW(s_shadowmap0, 4);
SAMPLER2DSHADOW(s_shadowmap1, 5);
SAMPLER2DSHADOW(s_shadowmap2, 6);
SAMPLER2DSHADOW(s_shadowmap3, 7);
#endif

#define CALC_SHADOW_TEXCOORD(_wpos)	v_sm_coord0 = mul(directional_viewproj[0], _wpos);\
	v_sm_coord1 = mul(directional_viewproj[1], _wpos);\
	v_sm_coord2 = mul(directional_viewproj[2], _wpos);\
	v_sm_coord3 = mul(directional_viewproj[3], _wpos);

bool is_texcoord_in_range(vec2 _texcoord, float minv, float maxv)
{
	return 	all(greaterThan(_texcoord, vec2_splat(minv))) && 
			all(lessThan   (_texcoord, vec2_splat(maxv)));
}

bool is_proj_texcoord_in_range(vec4 texcoord, float minv, float maxv)
{
	return is_texcoord_in_range(texcoord.xy/texcoord.w, minv, maxv);
}

// void calc_shadow_coord(inout vec4 pos, vec4 normal,
// 	out vec4 sm_coord0, 
// 	out vec4 sm_coord1, 
// 	out vec4 sm_coord2, 
// 	out vec4 sm_coord3)
// {
// 	pos = vec4(pos.xyz + normal.xyz * u_normaloffset, 1.0);
// 	vec4 wpos = mul(u_model[0], pos);

// 	sm_coord0 = mul(directional_viewproj[0], wpos);
// 	sm_coord1 = mul(directional_viewproj[1], wpos);
// 	sm_coord2 = mul(directional_viewproj[2], wpos);
// 	sm_coord3 = mul(directional_viewproj[3], wpos);
// }

float hardShadow(
	#ifdef SM_LINEAR
	sampler2D _sampler, 
	#else
	sampler2DShadow _sampler,
	#endif
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
	float occluder = unpackRgbaToFloat(texture2D(_sampler, tc) );
	return step(receiver, occluder);
#else
	vec4 coord = _shadowCoord;
	coord.z += _bias * _shadowCoord.w;
	return bgfxShadow2DProj(_sampler, _shadowCoord);
#endif
}