$input v_texcoord0, v_lightdirTS, v_viewdirTS, v_packed_info, v_sm_coord0, v_sm_coord1, v_sm_coord2, v_sm_coord3

#define v_normal_Y_angle	v_packed_info.x
#define v_distanceVS		v_packed_info.y
/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

#include "common/shadow.sh"

SAMPLER2D(s_basecolor, 	0);
SAMPLER2D(s_normal, 		1);

uniform vec4 u_fog_color;
uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

float compute_csm_visible(vec4 sm_coord0, vec4 sm_coord1, vec4 sm_coord2, vec4 sm_coord3, out vec3 color_coverage)
{
	ivec4 selections = ivec4(
		is_proj_texcoord_in_range(sm_coord0, 0.01, 0.99),
		is_proj_texcoord_in_range(sm_coord1, 0.01, 0.99),
		is_proj_texcoord_in_range(sm_coord2, 0.01, 0.99),
		is_proj_texcoord_in_range(sm_coord3, 0.01, 0.99));

	if (selections[0])
	{
		float coverage = float(selections[0]) * 0.4;
		color_coverage = vec3(-coverage, coverage, -coverage);
		return hardShadow(s_shadowmap0, sm_coord0, u_shadowmap_bias);
	}
	else if (selections[1])
	{
		float coverage = float(selections[1]) * 0.4;
		color_coverage = vec3(coverage, coverage, -coverage);
		return hardShadow(s_shadowmap1, sm_coord1, u_shadowmap_bias);
	}
	else if (selections[2])
	{
		float coverage = float(selections[2]) * 0.4;
		color_coverage = vec3(-coverage, -coverage, coverage);
		return hardShadow(s_shadowmap2, sm_coord2, u_shadowmap_bias);
	}
	else
	{
		float coverage = float(selections[3]) * 0.4;
		color_coverage = vec3(coverage, -coverage, -coverage);
		return hardShadow(s_shadowmap3, sm_coord3, u_shadowmap_bias);
	}
}

void main()
{
	vec3 color_coverage = vec3_splat(0.0);
	float visibility	= compute_csm_visible(v_sm_coord0, v_sm_coord1, v_sm_coord2, v_sm_coord3, color_coverage);

	vec4 ntexdata 	= texture2D(s_normal, v_texcoord0.xy);
	float gloss 	= ntexdata.z;
	vec3 normal 	= unproject_noraml(ntexdata.xy);

	vec4 basecolor  = texture2D(s_basecolor, v_texcoord0.xy);
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	
	vec4 ambientcolor = calc_ambient_color(ambient_mode.x, v_normal_Y_angle) * basecolor;

	vec4 fog_factor= calc_fog(u_fog_color, 0.0035, 1.442695, v_distanceVS);
    
	vec4 scenecolor	= saturate(ambientcolor + calc_lighting_BH(normal, v_lightdirTS, v_viewdirTS, lightcolor, 
															basecolor, u_specularColor, gloss, u_specularLight.x));
	vec4 finalcolor = vec4(mix(u_shadow_color.rgb, scenecolor.rgb, visibility), scenecolor.a);

	gl_FragColor = mix(u_fog_color, finalcolor, fog_factor);
}
