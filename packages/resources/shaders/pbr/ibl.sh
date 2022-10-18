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
#ifdef ENABLE_BENT_NORMAL
    vec3 N = mi.N;
#else //!ENABLE_BENT_NORMAL
    vec3 N = mi.bent_normal;
#endif //ENABLE_BENT_NORMAL
    return textureCube(s_irradiance, N).rgb * mi.albedo;
}

vec3 get_IBL_radiance_GGX(in material_info mi)
{
    const float last_mipmap = u_ibl_prefilter_mipmap_count-1.0; //make roughness [0, 1] to [0, last_mipmap]
    const float lod = clamp(mi.perceptual_roughness*last_mipmap, 0.0, last_mipmap);

    const vec2 lut_uv = vec2(mi.NdotV, mi.perceptual_roughness);
    const vec2 lut = texture2D(s_LUT, lut_uv).rg;
    const vec3 specular_light = textureCubeLod(s_prefilter, mi.reflect_vector, lod).rgb;
    return specular_light * (mi.f0 * lut.x + lut.y);
}

#endif //_IBL_SH_