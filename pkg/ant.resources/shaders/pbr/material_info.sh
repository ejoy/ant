#ifndef _MATERIAL_INFO_SH_
#define _MATERIAL_INFO_SH_

struct material_info
{
    vec3 albedo;

    vec3 f0;
    float f90;

    float roughness;
    float perceptual_roughness;

    float metallic;
    vec3 reflect_vector;

    vec3 N;
    vec3 V;

    float NdotV;
    float NdotL;

    // Energy compensation for multiple scattering in a microfacet model
    // See "Multiple-Scattering Microfacet BSDFs with the Smith Model"
    vec3 DFG;
    float energy_compensation;

#ifdef ENABLE_BENT_NORMAL
    mediump vec3 bent_normal;
#endif //ENABLE_BENT_NORMAL
};

#include "pbr/common.sh"
#include "pbr/input_attributes.sh"
#include "pbr/ibl.sh"

void calc_reflectance(in input_attributes input_attribs, inout material_info mi)
{
    vec3 f0_ior = vec3_splat(MIN_ROUGHNESS);
    mi.f0 = lerp(f0_ior, input_attribs.basecolor.rgb, input_attribs.metallic);
    mi.f90 = saturate(dot(mi.f0, vec3_splat(50.0 * 0.33)));

    mi.albedo = input_attribs.basecolor.rgb * (1.0 - mi.metallic);
}

material_info init_material_info(in input_attributes input_attribs)
{
    material_info mi = (material_info)0;

    mi.metallic = input_attribs.metallic;
    mi.perceptual_roughness = input_attribs.perceptual_roughness;
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.roughness = mi.perceptual_roughness * mi.perceptual_roughness;

    mi.N = input_attribs.N;
    mi.V = input_attribs.V;
    mi.NdotV = saturate(dot(mi.N, mi.V));
    mi.NdotL = 0.0;

#ifdef ENABLE_BENT_NORMAL
    mi.bent_normal = input_attribs.bent_normal;
#endif //ENABLE_BENT_NORMAL

    mi.reflect_vector = normalize(reflect(-mi.V, mi.N));
    
    calc_reflectance(input_attribs, mi);

    mi.DFG = get_IBL_DFG(mi.f0, mi.f90, mi.NdotV, mi.perceptual_roughness);
    mi.energy_compensation = 1.0 + mi.f0 * (1.0 / mi.DFG.y - 1.0);
    return mi;
}

#endif //_MATERIAL_INFO_SH_