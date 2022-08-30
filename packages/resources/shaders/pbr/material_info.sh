#ifndef _MATERIAL_INFO_SH_
#define _MATERIAL_INFO_SH_
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
};

float clamp_dot(vec3 x, vec3 y)
{
    return clamp(dot(x, y), 0.0, 1.0);
}

void calc_reflectance(vec3 basecolor, float metallic, out vec3 f0, out vec3 f90, out vec3 albedo)
{
    vec3 f0_ior = vec3_splat(MIN_ROUGHNESS);
    f0 = mix(f0_ior, basecolor, metallic);

    albedo = mix(basecolor * (1.0-f0_ior),  vec3_splat(0.0), metallic);
    // Compute reflectance.
    float reflectance = max(f0.r, max(f0.g, f0.b));

    // Anything less than 2% is physically impossible and is instead considered to be shadowing. Compare to "Real-Time-Rendering" 4th editon on page 325.
    f90 = vec3_splat(clamp(reflectance * 50.0, 0.0, 1.0));
}

material_info init_material_info(float metallic, float perceptual_roughness, vec3 basecolor, vec3 N, vec3 V)
{
    material_info mi;

    mi.metallic = metallic;
    mi.perceptual_roughness = perceptual_roughness;
    // Roughness is authored as perceptual roughness; as is convention,
    // convert to material roughness by squaring the perceptual roughness.
    mi.roughness = perceptual_roughness * perceptual_roughness;

    mi.N = N;
    mi.V = V;
    mi.NdotV = clamp_dot(N, V);

    calc_reflectance(basecolor, metallic, mi.f0, mi.f90, mi.albedo);
    return mi;
}

#endif //_MATERIAL_INFO_SH_