#ifndef __MATERIAL_INIT_SH__
#define __MATERIAL_INIT_SH__

#include "pbr/material_info.sh"

#include "common/utils.sh"

#include "pbr/common.sh"
#include "pbr/ibl.sh"

#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

vec4 get_basecolor(mediump vec2 texcoord, mediump vec4 basecolor)
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

vec4 get_emissive_color(vec2 texcoord)
{
    vec4 emissivecolor = u_emissive_factor;
#ifdef HAS_EMISSIVE_TEXTURE
    emissivecolor *= texture2D(s_emissive, texcoord);
#endif //HAS_EMISSIVE_TEXTURE
    return emissivecolor;
}

void fetch_metallic_roughness(in FSInput fsinput, inout material_info mi)
{
    mi.metallic = u_metallic_factor;
    mi.perceptual_roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    vec4 mrSample = texture2D(s_metallic_roughness, fsinput.uv0);
    mi.perceptual_roughness *= mrSample.g;
    mi.metallic *= mrSample.b;
#endif //HAS_METALLIC_ROUGHNESS_TEXTURE

    mi.perceptual_roughness  = clamp(mi.perceptual_roughness, 1e-6, 1.0);
    mi.metallic              = clamp(mi.metallic, 1e-6, 1.0);
}

void fetch_occlusion(in FSInput fsinput, inout material_info mi)
{
#ifdef HAS_OCCLUSION_TEXTURE
    mi.occlusion = texture2D(s_occlusion,  fsinput.uv0).r;
#else //!HAS_OCCLUSION_TEXTURE
    mi.occlusion = 1.0;
#endif //HAS_OCCLUSION_TEXTURE
    mi.occlusion *= u_occlusion_strength;
}

vec3 fetch_normal_from_tex(sampler2D normaltex, vec2 texcoord)
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
	mediump vec3 normalTS = fetch_normal_from_tex(s_normal, texcoord);
    // same as: mul(transpose(tbn), normalTS)
    return normalize(mul(normalTS, tbn));
}
#endif //HAS_NORMAL_TEXTURE

void fetch_normal(in FSInput fsinput, inout material_info mi)
{
#ifndef MATERIAL_UNLIT
    mi.gN = normalize(fsinput.normal);

#   ifdef HAS_NORMAL_TEXTURE
#       ifdef CALC_TBN
    mat3 tbn = cotangent_frame(mi.gN, fsinput.pos, fsinput.uv0);
    mi.T = tbn[0];
    mi.B = tbb[1];
#       else //!CALC_TBN
    mi.T = normalize(fsinput.tangent);
    mi.B = cross(mi.gN, mi.T);
    mat3 tbn = mat3(mi.T, mi.B, mi.gN);
#       endif //CALC_TBN
    mi.N = normal_from_tangent_frame(tbn, fsinput.uv0);
#   else  //!HAS_NORMAL_TEXTURE
    mi.N = mi.gN;
#endif //HAS_NORMAL_TEXTURE

#ifdef WITH_DOUBLE_SIDE
    if (fsinput.is_frontfacing){
#ifdef HAS_NORMAL_TEXTURE
        mi.T = -mi.T;
        mi.B = -mi.B;
#endif //HAS_NORMAL_TEXTURE
        mi.N = -mi.N;
        mi.gN = -mi.gN;
    }
#endif //WITH_DOUBLE_SIDE

#endif //!MATERIAL_UNLIT
}

void fetch_bent_normal(in FSInput fsinput, inout material_info mi)
{
#ifdef ENABLE_BENT_NORMAL
    //TODO: need bent_normal should come from ssao or other place
    const vec3 bent_normalTS = vec3(0.0, 0.0, 1.0);
    mi.bent_normal = bent_normalTS;
#endif //ENABLE_BENT_NORMAL
}

void default_init_material_info(in FSInput fsinput, inout material_info mi)
{
    mi.posWS        = fsinput.pos.xyz;
    mi.distanceVS   = fsinput.pos.w;
    mi.basecolor    = get_basecolor(fsinput.uv0, fsinput.color);
    mi.emissive     = get_emissive_color(fsinput.uv0);

    mi.V            = normalize(u_eyepos.xyz - fsinput.pos.xyz);
    mi.screen_uv = calc_normalize_fragcoord(fsinput.frag_coord.xy);
#ifdef USING_LIGHTMAP
    mi.lightmap_uv  = fsinput.uv1;
#endif //USING_LIGHTMAP
    mi.fragcoord    = fsinput.frag_coord;

    fetch_normal(fsinput, mi);
    fetch_bent_normal(fsinput, mi);
    fetch_metallic_roughness(fsinput, mi);
    fetch_occlusion(fsinput, mi);
}


#endif //!__MATERIAL_INIT_SH__