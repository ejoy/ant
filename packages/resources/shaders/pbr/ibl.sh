#ifndef _IBL_SH_
#define _IBL_SH_

// IBL
SAMPLERCUBE(s_irradiance,       5);
SAMPLERCUBE(s_prefilter,        6);
SAMPLER2D(s_LUT,                7);

uniform vec4 u_ibl_param;
#define u_ibl_prefilter_mipmap_count    u_ibl_param.x
#define u_ibl_indirect_intensity        u_ibl_param.y

#include "pbr/material_info.sh"

vec3 get_IBL_radiance_Lambertian(in material_info mi)
{
    return textureCube(s_irradiance, mi.N).rgb * mi.albedo;
}

vec3 get_IBL_radiance_GGX(in material_info mi)
{
    float last_mipmap = u_ibl_prefilter_mipmap_count-1.0; //make roughness [0, 1] to [0, last_mipmap]
    float lod = clamp(mi.perceptual_roughness*last_mipmap, 0.0, last_mipmap);
    vec3 reflection = normalize(reflect(-mi.V, mi.N));

    vec2 lut_uv = clamp(vec2(mi.NdotV, mi.perceptual_roughness), vec2_splat(0.0), vec2_splat(1.0));
    vec2 lut = texture2D(s_LUT, lut_uv).rg;
    vec3 specular_light = textureCubeLod(s_prefilter, reflection, lod).rgb;
    return specular_light * (mi.f0 * lut.x + lut.y);
}

vec3 calc_indirect_light(in material_info mi)
{
    vec3 indirect_color =   get_IBL_radiance_GGX(mi) +
                            get_IBL_radiance_Lambertian(mi);
    return indirect_color * u_ibl_indirect_intensity;
}

#endif //_IBL_SH_