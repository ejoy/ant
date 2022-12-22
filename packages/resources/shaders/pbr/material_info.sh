#ifndef _MATERIAL_INFO_SH_
#define _MATERIAL_INFO_SH_

#include "pbr/common.sh"
#include "pbr/input_attributes.sh"

struct material_info
{
    mediump float perceptual_roughness;// roughness value, as authored by the model creator (input to shader)
    mediump vec3 f0;                   // full reflectance color (n incidence angle)

    mediump float roughness;            // roughness mapped to a more linear change in the roughness (proposed by [2])
    mediump vec3 albedo;

    mediump vec3 f90;                   // reflectance color at grazing angle
    mediump float metallic;

    mediump vec3 N;
    mediump float NdotV;
    mediump vec3 V;
    mediump float NdotL;

    mediump vec3 reflect_vector;

#ifdef ENABLE_BENT_NORMAL
    mediump vec3 bent_normal;
#endif //ENABLE_BENT_NORMAL
    // mediump vec3 DFG;
};

mediump float clamp_dot(mediump vec3 x, mediump vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

void calc_reflectance(in input_attributes input_attribs, inout material_info mi)
{
    mediump vec3 f0_ior = mediump vec3_splat(MIN_ROUGHNESS);
    mi.f0 = mix(f0_ior, input_attribs.basecolor.rgb, input_attribs.metallic);

    mi.albedo = mix(input_attribs.basecolor.rgb * (1.0-f0_ior),  mediump vec3_splat(0.0), input_attribs.metallic);
    // Compute reflectance.
    mediump float reflectance = max(mi.f0.r, max(mi.f0.g, mi.f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    mi.f90 = mediump vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));
}

material_info init_material_info(in input_attributes input_attribs)
{
    material_info mi;

    mi.metallic = input_attribs.metallic;
    mi.perceptual_roughness = input_attribs.perceptual_roughness;
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.roughness = mi.perceptual_roughness * mi.perceptual_roughness;

    mi.N = input_attribs.N;
    mi.V = input_attribs.V;
    mi.NdotV = clamp_dot(mi.N, mi.V);
    mi.NdotL = 0.0;

#ifdef ENABLE_BENT_NORMAL
    mi.bent_normal = input_attribs.bent_normal;
#endif //ENABLE_BENT_NORMAL

    mi.reflect_vector = normalize(reflect(-mi.V, mi.N));
    
    calc_reflectance(input_attribs, mi);
    return mi;
}

#endif //_MATERIAL_INFO_SH_