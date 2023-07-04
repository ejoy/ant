#ifndef __TERRAIN_SH__
#define __TERRAIN_SH__
#include "pbr/attribute_define.sh"
#include "pbr/attribute_uniforms.sh"

vec2 texture2DArrayBc5(sampler2DArray _sampler, vec3 _uv)
{
#if BGFX_SHADER_LANGUAGE_HLSL && BGFX_SHADER_LANGUAGE_HLSL <= 300
	return texture2DArray(_sampler, _uv).yx;
#else
	return texture2DArray(_sampler, _uv).xy;
#endif
}

mediump vec3 terrain_normal_from_tangent_frame(mat3 tbn, mediump vec2 texcoord, mediump float normal_idx)
{
	mediump vec3 normalTS = remap_normal(texture2DArrayBc5(s_normal, mediump vec3(texcoord, normal_idx)));
	// same as: mul(transpose(tbn), normalTS)
    return normalize(mul(normalTS, tbn));
}

vec3 blend_terrain_color(vec3 sand_basecolor, vec3 stone_basecolor, float sand_height, float sand_alpha)
{
    float sand_weight = min(1.0, 2.5 * abs(sand_height - sand_alpha));
    float stone_weight = 1 - sand_weight;
    return stone_basecolor*stone_weight + sand_basecolor*sand_weight;
}

#endif //
