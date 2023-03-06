#ifndef _IBL_SH_
#define _IBL_SH_

// IBL

#ifdef IRRADIANCE_SH_BAND_NUM
uniform vec4 u_irradianceSH[IRRADIANCE_SH_BAND_NUM*IRRADIANCE_SH_BAND_NUM];

vec3 compute_irradiance_SH(vec3 N)
{
    return max(
          u_irradianceSH[0].rgb
#if IRRADIANCE_SH_BAND_NUM >= 2
        + u_irradianceSH[1].rgb * (N.y)
        + u_irradianceSH[2].rgb * (N.z)
        + u_irradianceSH[3].rgb * (N.x)
#endif
#if IRRADIANCE_SH_BAND_NUM >= 3
        + u_irradianceSH[4].rgb * (N.y * N.x)
        + u_irradianceSH[5].rgb * (N.y * N.z)
        + u_irradianceSH[6].rgb * (3.0 * N.z * N.z - 1.0)
        + u_irradianceSH[7].rgb * (N.z * N.x)
        + u_irradianceSH[8].rgb * (N.x * N.x - N.y * N.y)
#endif
        , 0.0);
}
#else //!IRRADIANCE_SH_BAND_NUM

SAMPLERCUBE(s_irradiance,       5);

#endif //IRRADIANCE_SH_BAND_NUM

uniform vec4 u_ibl_param;
#define u_ibl_prefilter_mipmap_count    u_ibl_param.x
#define u_ibl_indirect_intensity        u_ibl_param.y

#include "pbr/material_info.sh"

SAMPLERCUBE(s_prefilter,        6);
SAMPLER2D(s_LUT,                7);

vec3 get_IBL_radiance_Lambertian(in material_info mi)
{
#ifdef ENABLE_BENT_NORMAL
    vec3 N = mi.bent_normal;
#else //!ENABLE_BENT_NORMAL
    vec3 N = mi.N;
#endif //ENABLE_BENT_NORMAL

#ifdef IRRADIANCE_SH_BAND_NUM
    vec3 irradiancecolor = compute_irradiance_SH(N);
#else //!IRRADIANCE_SH_BAND_NUM
    vec3 irradiancecolor = textureCube(s_irradiance, N).rgb;
#endif //IRRADIANCE_SH_BAND_NUM
    return irradiancecolor * mi.albedo;
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