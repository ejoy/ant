#ifndef _MATERIAL_INFO_SH_
#define _MATERIAL_INFO_SH_

#include "pbr/common.sh"
#include "common/transform.sh"

struct material_info
{
    vec3 posWS;
    float distanceVS;

    vec4 basecolor;
    vec4 emissive;

    float occlusion;
    vec3 albedo;

    vec3 f0;
    float f90;

    vec3 reflect_vector;

    float metallic;
    float perceptual_roughness;
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    float roughness;    // perceptual_roughness * perceptual_roughness

    float NdotV;
    float NdotL;

    vec3 V;
    vec3 N;
    vec3 gN;

    vec3 T;
    vec3 B;

    vec4 fragcoord;
    vec2 screen_uv;
#ifdef USING_LIGHTMAP
    vec2 lightmap_uv;
#endif //USING_LIGHTMAP

    // Energy compensation for multiple scattering in a microfacet model
    // See "Multiple-Scattering Microfacet BSDFs with the Smith Model"
    vec3 DFG;
    vec3 energy_compensation;

#ifdef ENABLE_BENT_NORMAL
    vec3 bend_normal;
#endif //ENABLE_BENT_NORMAL
};

#include "pbr/ibl.sh"

void build_material_info(inout material_info mi)
{
//should discard after all texture sample is done. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
#ifdef ALPHAMODE_MASK
    if(mi.basecolor.a < u_alpha_mask_cutoff)
        discard;
    mi.basecolor.a = 1.0;
#endif //ALPHAMODE_MASK

    mi.NdotV            = saturate(dot(mi.N, mi.V));

    mi.roughness        = mi.perceptual_roughness * mi.perceptual_roughness;

    mi.reflect_vector   = normalize(reflect(-mi.V, mi.N));

    mi.f0               = lerp(vec3_splat(MIN_ROUGHNESS), mi.basecolor.rgb, mi.metallic);
    mi.f90              = saturate(dot(mi.f0, vec3_splat(50.0 * 0.33)));

    mi.albedo           = mi.basecolor.rgb * (1.0 - mi.metallic);

    mi.DFG              = get_IBL_DFG(mi.f0, mi.f90, mi.NdotV, mi.perceptual_roughness);
    mi.energy_compensation = vec3_splat(1.0); //1.0 + mi.f0 * (1.0 / mi.DFG.y - 1.0);
    get_viewspace_depth(mi.distanceVS);
}

#endif //_MATERIAL_INFO_SH_