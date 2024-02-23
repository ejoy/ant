#ifndef __SHADOW_UTILS_SH__
#define __SHADOW_UTILS_SH__

#include "common/shadow/define.sh"

bool is_texcoord_in_range(vec2 _texcoord, float minv, float maxv)
{
	return 	all(greaterThan(_texcoord, vec2_splat(minv))) && 
			all(lessThan   (_texcoord, vec2_splat(maxv)));
}

bool is_proj_texcoord_in_range(vec4 texcoord, float minv, float maxv)
{
	return is_texcoord_in_range(texcoord.xy/texcoord.w, minv, maxv);
}

float sample_shadow_hardware(sampler2DShadow shadowsampler, vec4 shadowcoord)
{
	return shadow2DProj(shadowsampler, shadowcoord);
}

float sample_shadow_directly(sampler2D shadowsampler, vec4 shadowcoord)
{
	vec2 uv = shadowcoord.xy/shadowcoord.w;
	float receiver = (shadowcoord.z)/shadowcoord.w;
	float occluder = texture2D(shadowsampler, uv).x;
	return step(occluder, receiver);
}

#endif //__SHADOW_UTILS_SH__