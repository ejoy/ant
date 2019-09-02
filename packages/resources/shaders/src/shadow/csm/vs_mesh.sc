$input a_position, a_normal, a_tangent, a_bitangent, a_texcoord0
$output v_packed_info, v_lightdirTS, v_viewdirTS, v_sm_coord0, v_sm_coord1, v_sm_coord2, v_sm_coord3

/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"

#include "common/uniforms.sh"
#include "common/lighting.sh"

#include "common/shadow.sh"

void main()
{
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0) );

	vec3 offset_pos = vec4(a_position.xyz + a_normal.xyz * u_normaloffset, 1.0);
	vec4 wpos 	= mul(u_model[0], offset_pos);

	vec3 normalWS = normalize(mul(u_model[0], vec4(a_normal.xyz, 0.0)).xyz);
	v_packed_info.x = normalWS.y;

	vec3 posVS = mul(u_modelView, vec4(a_position, 1.0)).xyz;
	v_packed_info.y = posVS.z;

	// tbn from world space to tangent space
	mat3 tbn 	= calc_tbn_lh_ex(a_normal.xyz, a_tangent.xyz, a_tangent.w, u_model[0]);

	v_lightdirTS= mul(directional_lightdir[0].xyz , tbn);
	v_viewdirTS = mul(normalize(u_eyepos - wpos).xyz, tbn);	

	v_texcoord0 = a_texcoord0;

	CALC_SHADOW_TEXCOORD(wpos);
}
