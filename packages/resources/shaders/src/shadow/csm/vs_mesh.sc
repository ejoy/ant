$input a_position, a_normal, a_tangent
$output v_normalVS, v_posVS, v_sm_coord0, v_sm_coord1, v_sm_coord2, v_sm_coord3

/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"

#include "common/uniforms.sh"
#include "shadow_common.sh"

void main()
{
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0) );

	vec3 offset_pos = vec4(a_position.xyz + a_normal.xyz * u_normaloffset, 1.0);
	vec4 wpos 	= mul(u_model[0], offset_pos);

	v_normalVS 	= normalize(mul(u_modelView, vec4(a_normal.xyz, 0.0) ).xyz);
	v_posVS  	= mul(u_modelView, vec4(a_position, 1.0)).xyz;

	// tbn from world space to tangent space
	mat3 tbn = calc_tbn_lh_ex(a_normal.xyz, a_tangent.xyz, a_tangent.w, u_model[0]);

	v_lightdir 	= mul(directional_lightdir[0].xyz , tbn);
	v_viewdir 	= mul(normalize(u_eyepos - wpos).xyz, tbn);	

	v_position = mul(u_modelView, offset_pos);

	v_sm_coord0 = mul(directional_viewproj[0], wpos);
	v_sm_coord1 = mul(directional_viewproj[1], wpos);
	v_sm_coord2 = mul(directional_viewproj[2], wpos);
	v_sm_coord3 = mul(directional_viewproj[3], wpos);
}
