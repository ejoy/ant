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

#if BGFX_SHADER_LANGUAGE_HLSL || BGFX_SHADER_LANGUAGE_METAL || BGFX_SHADER_LANGUAGE_SPIRV
float bgfxShadow2DArrayProj(BgfxSampler2DArrayShadow _sampler, vec4 _coord, uint layer)
{
    vec3 coord = _coord.xyz * rcp(_coord.w);
	return _sampler.m_texture.SampleCmp(_sampler.m_sampler, vec3(coord.xy, layer), coord.z);
}
#endif //!(hlsl&metal&spirv)

#define shadow2DArrayProj bgfxShadow2DArrayProj

float sample_shadow_compare(sampler2DArrayShadow shadowsampler, vec4 shadowcoord, uint cascadeidx)
{
	//TODO: need implement shadow2DArrayProjOffset, offset with integer(ivec2)
	return shadow2DArrayProj(shadowsampler, shadowcoord, cascadeidx);
}

float sample_shadow_directly(sampler2DArray shadowsampler, vec4 shadowcoord, uint cascadeidx)
{
	vec2 uv = shadowcoord.xy/shadowcoord.w;
	float receiver = (shadowcoord.z)/shadowcoord.w;
	float occluder = texture2DArray(shadowsampler, vec3(uv, cascadeidx)).x;
	return step(occluder, receiver);
}

#endif //__SHADOW_UTILS_SH__