#ifndef _TERRAIN_MATERIAL_INFO_SH_
#define _TERRAIN_MATERIAL_INFO_SH_

#include "pbr/common.sh"
#include "terrain_input_attributes.sh"

struct material_info
{
    float perceptual_roughness;// roughness value, as authored by the model creator (input to shader)
    vec3 f0;                   // full reflectance color (n incidence angle)

    float roughness;     // roughness mapped to a more linear change in the roughness (proposed by [2])
    vec3 albedo;

    vec3 f90;             // reflectance color at grazing angle
    float metallic;

    vec3 N;
    float NdotV;
    vec3 V;
    // float padding;
    // vec3 DFG;
};

float clamp_dot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

void calc_reflectance(in input_attributes input_attribs, inout material_info mi)
{
    vec3 f0_ior = vec3_splat(MIN_ROUGHNESS);
    mi.f0 = mix(f0_ior, input_attribs.basecolor.rgb, input_attribs.metallic);

    mi.albedo = mix(input_attribs.basecolor.rgb * (1.0-f0_ior),  vec3_splat(0.0), input_attribs.metallic);
    // Compute reflectance.
    float reflectance = max(mi.f0.r, max(mi.f0.g, mi.f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    mi.f90 = vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));
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

    calc_reflectance(input_attribs, mi);
    return mi;
}

#endif //_TERRAIN_MATERIAL_INFO_SH_