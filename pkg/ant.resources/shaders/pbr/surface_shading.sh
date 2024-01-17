#ifndef __SURFACE_SHADING_SH__
#define __SURFACE_SHADING_SH__

// code from filament|shading_model_standard.fs

#include "common/math.sh"

#ifndef SHADING_WITH_HIGH_QUALITY
#define SHADING_WITH_HIGH_QUALITY 1
#endif //

//------------------------------------------------------------------------------
// Specular BRDF implementations
//------------------------------------------------------------------------------

float D_GGX(float roughness, float NdotH, vec3 h, vec3 N) {
    // Walter et al. 2007, "Microfacet Models for Refraction through Rough Surfaces"

    // In mediump, there are two problems computing 1.0 - NdotH^2
    // 1) 1.0 - NdotH^2 suffers floating point cancellation when NdotH^2 is close to 1 (highlights)
    // 2) NdotH doesn't have enough precision around 1.0
    // Both problem can be fixed by computing 1-NdotH^2 in highp and providing NdotH in highp as well

    // However, we can do better using Lagrange's identity:
    //      ||a x b||^2 = ||a||^2 ||b||^2 - (a . b)^2
    // since N and H are unit vectors: ||N x H||^2 = 1.0 - NdotH^2
    // This computes 1.0 - NdotH^2 directly (which is close to zero in the highlights and has
    // enough precision).
    // Overall this yields better performance, keeping all computations in mediump
#if SHADING_WITH_HIGH_QUALITY
    float oneMinusNoHSquared = 1.0 - NdotH * NdotH;
#else //!SHADING_WITH_HIGH_QUALITY
    vec3 NxH = cross(N, h);
    float oneMinusNoHSquared = dot(NxH, NxH);
#endif //SHADING_WITH_HIGH_QUALITY

    float a = NdotH * roughness;
    float k = roughness / (oneMinusNoHSquared + a * a);
    float d = k * k * (1.0 / PI);
    //return saturateMediump(d);
    return saturate(d);
}

float V_SmithGGXCorrelated(float roughness, float NdotV, float NdotL) {
    // Heitz 2014, "Understanding the Masking-Shadowing Function in Microfacet-Based BRDFs"
    float a2 = roughness * roughness;
    // TODO: lambdaV can be pre-computed for all the lights, it should be moved out of this function
    float lambdaV = NdotL * sqrt((NdotV - a2 * NdotV) * NdotV + a2);
    float lambdaL = NdotV * sqrt((NdotL - a2 * NdotL) * NdotL + a2);
    float v = 0.5 / (lambdaV + lambdaL);
    // a2=0 => v = 1 / 4*NdotL*NdotV   => min=1/4, max=+inf
    // a2=1 => v = 1 / 2*(NdotL+NdotV) => min=1/4, max=+inf
    // clamp to the maximum value representable in mediump
    //return saturateMediump(v);
    return saturate(v);
}

float V_SmithGGXCorrelated_Fast(float roughness, float NdotV, float NdotL) {
    // Hammon 2017, "PBR Diffuse Lighting for GGX+Smith Microsurfaces"
    float v = 0.5 / mix(2.0 * NdotL * NdotV, NdotL + NdotV, roughness);
    //return saturateMediump(v);
    return saturate(v);
}

float V_Neubelt(float NdotV, float NdotL) {
    // Neubelt and Pettineo 2013, "Crafting a Next-gen Material Pipeline for The Order: 1886"
    //return saturate(1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV)));
    return saturateMediump(1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV)));
}

vec3 F_Schlick(const vec3 f0, float f90, float VdotH) {
    // Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"
    return f0 + (f90 - f0) * pow5(1.0 - VdotH);
}

vec3 F_Schlick(const vec3 f0, float VdotH) {
    float f = pow(1.0 - VdotH, 5.0);
    return f + f0 * (1.0 - f);
}

float F_Schlick(float f0, float f90, float VdotH) {
    return f0 + (f90 - f0) * pow5(1.0 - VdotH);
}

///// Specular
float distribution(float roughness, float NdotH, vec3 h, vec3 N) {
    return D_GGX(roughness, NdotH, h, N);
}

float visibility(float roughness, float NdotV, float NdotL) {
#if SHADING_WITH_HIGH_QUALITY
    return V_SmithGGXCorrelated(roughness, NdotV, NdotL);
#else //!SHADING_WITH_HIGH_QUALITY
    return V_SmithGGXCorrelated_Fast(roughness, NdotV, NdotL);
#endif //SHADING_WITH_HIGH_QUALITY
}

vec3 fresnel(vec3 f0, float LdotH) {
#if SHADING_WITH_HIGH_QUALITY
    float f90 = saturate(dot(f0, vec3_splat(50.0 * 0.33)));
    return F_Schlick(f0, f90, LdotH);
#else //!SHADING_WITH_HIGH_QUALITY
    return F_Schlick(f0, LdotH); // f90 = 1.0
#endif //SHADING_WITH_HIGH_QUALITY
}

vec3 specular_lobe(material_info mi, light_info light, vec3 h,
        float NdotH, float LdotH) {

    float D = distribution(mi.roughness, NdotH, h, mi.N);
    float V = visibility(mi.roughness, mi.NdotV, mi.NdotL);
    vec3  F = fresnel(mi.f0, LdotH);

    return (D * V) * F;
}

///////// diffuse
float Fd_Lambert() {
    return 1.0 / PI;
}

float Fd_Burley(float roughness, float NdotV, float NdotL, float LdotH) {
    // Burley 2012, "Physically-Based Shading at Disney"
    float f90 = 0.5 + 2.0 * roughness * LdotH * LdotH;
    float lightScatter = F_Schlick(1.0, f90, NdotL);
    float viewScatter  = F_Schlick(1.0, f90, NdotV);
    return lightScatter * viewScatter * (1.0 / PI);
}

vec3 diffuse_lobe(const material_info mi, float LdotH) {
#if SHADING_WITH_HIGH_QUALITY
    return mi.albedo * Fd_Burley(mi.roughness, mi.NdotV, mi.NdotL, LdotH);
#else //!SHADING_WITH_HIGH_QUALITY
    return mi.albedo * Fd_Lambert();
#endif //SHADING_WITH_HIGH_QUALITY
}

vec3 surface_shading(const material_info mi, const light_info light) {
    vec3 h = normalize(mi.V + light.pt2l);

    float NdotH = saturate(dot(mi.N, h));
    float LdotH = saturate(dot(light.pt2l, h));

    vec3 color =    diffuse_lobe(mi, LdotH) + 
                    specular_lobe(mi, light, h, NdotH, LdotH) * mi.energy_compensation;

    return (color * light.color.rgb) *
            (light.intensity * light.attenuation * mi.NdotL);
}
#endif //__SURFACE_SHADING_SH__