#ifndef __SHADOW_EVSM_SH__
#define __SHADOW_EVSM_SH__

#ifdef SM_EVSM
#include "common/shadow/evsm_utils.sh"

// float shadowEVSM(in float3 shadowPos, in float3 shadowPosDX,
//                           in float3 shadowPosDY, uint cascadeIdx)

#define u_shadow_filter_exponents	u_shadow_filter_param.xy
#define u_shadow_filter_bias		u_shadow_filter_param.z
#define u_shadow_filter_light_bleeding_reducation u_shadow_filter_param.w

float shadowEVSM(shadow_sampler_type shadowsampler, vec4 shadowcoord, int cascadeidx)
{
    vec2 wd = warp_depth(shadowcoord.z, u_shadow_filter_exponents);

	vec4 occluder = texture2DArray(shadowsampler, vec3(shadowcoord.xy, cascadeidx));

    // Derivative of warping at depth
    vec2 depthscale = u_shadow_filter_bias * 0.01 * u_shadow_filter_exponents * wd;
    vec2 variance = depthscale * depthscale;

#if EVSM_COMPONENT == 2
    return ChebyshevUpperBound(occluder.xy, wd.x, variance.x, u_shadow_filter_light_bleeding_reducation);
#endif //

#if EVSM_COMPONENT == 4
	float p = ChebyshevUpperBound(occluder.xz, wd.x, variance.x, u_shadow_filter_light_bleeding_reducation);
	float n = ChebyshevUpperBound(occluder.yw, wd.y, variance.y, u_shadow_filter_light_bleeding_reducation);
	return max(p, n);
#endif //
}
#endif //SM_EVSM

#endif //__SHADOW_EVSM_SH__