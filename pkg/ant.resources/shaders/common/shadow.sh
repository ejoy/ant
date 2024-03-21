/*
 * Copyright 2013-2014 Dario Manesku. All rights reserved.
 * License: https://github.com/bkaradzic/bgfx#license-bsd-2-clause
 */

 #ifndef __SHADER_SHADOW_SH__
 #define __SHADER_SHADOW_SH__

#ifdef ENABLE_SHADOW

#include "common/shadow/define.sh"
#include "common/shadow/utils.sh"
#include "common/shadow/filtering.sh"

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

	return sample_visibility(shadowcoord, cascadeidx);
}
#endif //ENABLE_SHADOW
#endif //__SHADER_SHADOW_SH__