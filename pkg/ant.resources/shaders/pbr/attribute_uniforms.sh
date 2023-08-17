#ifndef __INPUT_UNIFORMS_SH__
#define __INPUT_UNIFORMS_SH__

#include "pbr/attribute_define.sh"
#include "common/utils.sh"

#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

mediump vec4 get_basecolor(mediump vec2 texcoord, mediump vec4 basecolor)
{
    basecolor *= u_basecolor_factor;

#ifdef HAS_BASECOLOR_TEXTURE
    basecolor *= texture2D(s_basecolor, texcoord);
#endif//HAS_BASECOLOR_TEXTURE

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif //ALPHAMODE_OPAQUE
    return basecolor;
}

mediump vec4 get_emissive_color(mediump vec2 texcoord)
{
    mediump vec4 emissivecolor = u_emissive_factor;
#ifdef HAS_EMISSIVE_TEXTURE
    emissivecolor *= texture2D(s_emissive, texcoord);
#endif //HAS_EMISSIVE_TEXTURE
    return emissivecolor;
}

mediump vec3 remap_normal(mediump vec2 normalTSXY)
{
    mediump vec2 normalXY = normalTSXY * 2.0 - 1.0;
	mediump float z = sqrt(1.0 - dot(normalXY, normalXY));
    return mediump vec3(normalXY, z);
}

mediump vec3 fetch_normal(sampler2D normaltex, mediump vec2 texcoord)
{
    #if BX_PLATFORM_OSX || BX_PLATFORM_IOS || BX_PLATFORM_ANDROID
        return remap_normal(texture2DAstc(normaltex, texcoord));
    #else
        return remap_normal(texture2DBc5(normaltex, texcoord));
    #endif
}


#ifdef HAS_NORMAL_TEXTURE
mediump vec3 normal_from_tangent_frame(mat3 tbn, mediump vec2 texcoord)
{
	mediump vec3 normalTS = fetch_normal(s_normal, texcoord);
    // same as: mul(transpose(tbn), normalTS)
    return normalize(mul(normalTS, tbn));
}
#endif //HAS_NORMAL_TEXTURE

void get_metallic_roughness(mediump vec2 uv, inout input_attributes input_attribs)
{
    input_attribs.metallic = u_metallic_factor;
    input_attribs.perceptual_roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    mediump vec4 mrSample = texture2D(s_metallic_roughness, uv);
    input_attribs.perceptual_roughness *= mrSample.g;
    input_attribs.metallic *= mrSample.b;
#endif //HAS_METALLIC_ROUGHNESS_TEXTURE

    input_attribs.perceptual_roughness  = clamp(input_attribs.perceptual_roughness, 10e-4, 1.0);
    input_attribs.metallic              = clamp(input_attribs.metallic, 10e-4, 1.0);
}

void get_occlusion(mediump vec2 uv, inout input_attributes input_attribs)
{
#ifdef HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = texture2D(s_occlusion,  uv).r;
#else //!HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = 1.0;
#endif //HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion *= u_occlusion_strength;
}

#endif //__INPUT_UNIFORMS_SH__