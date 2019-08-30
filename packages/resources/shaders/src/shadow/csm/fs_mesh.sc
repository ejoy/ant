$input v_lightdirTS, v_viewdirTS, v_packed_info, v_texcoord0, v_sm_coord0, v_sm_coord1, v_sm_coord2, v_sm_coord3

#define v_normal_Y_angle	v_packed_info.x
#define v_distanceVS		v_packed_info.y
/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

#include "common/lighting.sh"

#include "shadow_common.sh"

float compute_csm_visible(ivec4 selections)
{
	if (selections[0])
	{
		float coverage = float(selections[0]) * 0.4;
		colorCoverage = vec3(-coverage, coverage, -coverage);
		return hardShadow(s_shadowMap0, hardShadow, u_shadowmap_bias);
	}
	else if (selections[1])
	{
		float coverage = float(selections[1]) * 0.4;
		colorCoverage = vec3(coverage, coverage, -coverage);
		return hardShadow(s_shadowMap1, hardShadow, u_shadowmap_bias);
	}
	else if (selections[2])
	{
		float coverage = float(selections[2]) * 0.4;
		colorCoverage = vec3(-coverage, -coverage, coverage);
		return hardShadow(s_shadowMap2, hardShadow, u_shadowmap_bias);
	}
	else
	{
		float coverage = float(selections[3]) * 0.4;
		colorCoverage = vec3(coverage, -coverage, -coverage);
		return hardShadow(s_shadowMap3, hardShadow, u_shadowmap_bias);
	}
}

SAMPLE2D(s_basecolor, 0);
SAMPLE2D(s_normal, 1);

uniform vec4 u_fog_color;
uniform vec4 u_specularColor;
uniform vec4 u_specularLight;

void main()
{
	vec3 colorCoverage = vec3_splat(0.0);
	float visibility = 0.0;

	ivec4 selections = ivec4(
		is_proj_texcoord_in_range(v_sm_coord0, 0.01, 0.99),
		is_proj_texcoord_in_range(v_sm_coord1, 0.01, 0.99),
		is_proj_texcoord_in_range(v_sm_coord2, 0.01, 0.99),
		is_proj_texcoord_in_range(v_sm_coord3, 0.01, 0.99));

	float visible 	= compute_csm_visible(selections);

	vec4 ntexdata 	= texture2D(s_normal, v_texcoord0.xy);
	float gloss 	= ntexdata.z;
	vec3 normal 	= unproject_noraml(ntexdata.xy);

	vec4 basecolor  = texture2D(s_basecolor, v_texcoord0.xy);
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	
	vec4 ambientcolor = calc_ambient_color(ambient_mode.x, v_normal_Y_angle) * basecolor;

	float fog_factor= calc_fog(u_fog_color, 0.0035, 1.442695, v_distanceVS);
    
	gl_FragColor 	= saturate(ambientcolor + calc_lighting_BH(normal, v_lightdir, v_viewdir, lightcolor, 
															basecolor, u_specularColor, gloss, u_specularLight.x));

	gl_FragColor.xyz = mix(fogColor, u_shadow_color, fog_factor);
	gl_FragColor.w = 1.0;
}
