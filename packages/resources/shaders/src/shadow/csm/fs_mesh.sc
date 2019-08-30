$input

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

void main()
{
	vec3 colorCoverage = vec3_splat(0.0);
	float visibility = 0.0;

	ivec4 selections = ivec4(
		is_proj_texcoord_in_range(v_sm_coord0, 0.01, 0.99),
		is_proj_texcoord_in_range(v_sm_coord1, 0.01, 0.99),
		is_proj_texcoord_in_range(v_sm_coord2, 0.01, 0.99),
		is_proj_texcoord_in_range(v_sm_coord3, 0.01, 0.99));

	float visible = compute_csm_visible(selections);

	vec3 fogColor = vec3_splat(0.0);
	float fog_factor = calc_fog(fogColor, 0.0035, 1.442695, length(v_posVS))

	gl_FragColor.xyz = mix(fogColor, u_shadow_color, fog_factor);
	gl_FragColor.w = 1.0;
}
