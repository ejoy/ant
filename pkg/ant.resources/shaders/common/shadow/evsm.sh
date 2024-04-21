#ifndef __SHADOW_EVSM_SH__
#define __SHADOW_EVSM_SH__

#ifdef SM_EVSM
#include "common/shadow/evsm_utils.sh"

// float shadowEVSM(in float3 shadowPos, in float3 shadowPosDX,
//                           in float3 shadowPosDY, uint cascadeIdx)

#define u_shadow_filter_exponents	    u_shadow_filter_param.xy
#define u_shadow_filter_depth_scale	    u_shadow_filter_param.z
#define u_shadow_filter_light_bleeding  u_shadow_filter_param.w

float shadowEVSM(shadow_sampler_type shadowsampler, vec4 shadowcoord, int cascadeidx)
{
    vec2 wd = warp_depth(shadowcoord.z, u_shadow_filter_exponents);

	vec4 occluder = texture2DArray(shadowsampler, vec3(shadowcoord.xy, cascadeidx));
    // Derivative of warping at depth
    vec2 depthscale = u_shadow_filter_depth_scale * u_shadow_filter_exponents * wd;
    vec2 variance = depthscale * depthscale;

#if EVSM_COMPONENT == 2
    // why 1.0 - 
    const float visibility = chebyshev_upper_bound(occluder.xy, wd.x, variance.x, u_shadow_filter_light_bleeding);
    
#endif //

#if EVSM_COMPONENT == 4
	float p = chebyshev_upper_bound(occluder.xz, wd.x, variance.x, u_shadow_filter_light_bleeding);
	float n = chebyshev_upper_bound(occluder.yw, wd.y, variance.y, u_shadow_filter_light_bleeding);
	const float visibility = min(p, n);
#endif //

    //why need 1.0 - visibility, because we using inverse-z
    return visibility;
}
#endif //SM_EVSM

#endif //__SHADOW_EVSM_SH__