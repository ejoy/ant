#ifndef __SURFACE_SHADING_SH__
#define __SURFACE_SHADING_SH__

// code from filament|shading_model_standard.fs

#include "common/math.sh"
#include "direct_specular.sh"
#ifndef SHADING_WITH_HIGH_QUALITY
#define SHADING_WITH_HIGH_QUALITY 1
#endif //

#define USE_DIRECT_SPECULAR_LUT

#ifdef USE_DIRECT_SPECULAR_LUT
SAMPLER2D(s_direct_specular,                13);
#endif // USE_DIRECT_SPECULAR_LUT


//------------------------------------------------------------------------------
// Specular BRDF implementations
//------------------------------------------------------------------------------

float D_GGX(float roughness, float NdotH) {

    float a = NdotH * roughness;
    //Since roughness set to 10e-6 at initialization, the denominator must be greater than 0
    float denom = 1.0 - NdotH * NdotH + a * a;
    float k = roughness * rcp(denom);
    return k * k * (1.0 / PI);

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
    float a = roughness;
    float GGXV = NdotL * (NdotV * (1.0 - a) + a);
    float GGXL = NdotV * (NdotL * (1.0 - a) + a);
    return 0.5 / (GGXV + GGXL);
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
float distribution(float roughness, float NdotH) {
    return D_GGX(roughness, NdotH);
}

float visibility(float roughness, float NdotV, float NdotL) {
return V_SmithGGXCorrelated_Fast(roughness, NdotV, NdotL);
}

vec3 fresnel(vec3 f0, float LdotH) {
#if SHADING_WITH_HIGH_QUALITY
    float f90 = saturate(dot(f0, vec3_splat(50.0 * 0.33)));
    return F_Schlick(f0, f90, LdotH);
#else //!SHADING_WITH_HIGH_QUALITY
    return F_Schlick(f0, LdotH); // f90 = 1.0
#endif //SHADING_WITH_HIGH_QUALITY
}

float G1V(float dotNV, float k)
{
	return 1.0f/(dotNV*(1.0f-k)+k);
}

vec3 specular_lobe(material_info mi, light_info light, vec3 h,
        float NdotH, float LdotH) {
//http://filmicworlds.com/blog/optimizing-ggx-shaders-with-dotlh/
#ifdef USE_DIRECT_SPECULAR_LUT
	float D = texture2D(s_direct_specular, vec2(NdotH, mi.roughness)).x;
    vec2 FV_helper = texture2D(s_direct_specular, vec2(LdotH, mi.roughness)).yz;
#else //!USE_DIRECT_SPECULAR_LUT
    float D = LightingFuncGGX_D(NdotH, mi.roughness);
    vec2 FV_helper = LightingFuncGGX_FV(LdotH, mi.roughness);
#endif // USE_DIRECT_SPECULAR_LUT 
	vec3 FV = mi.f0 * FV_helper.x + vec3_splat(FV_helper.y);
	return mi.NdotL * D * FV;
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
    color *= light.color.rgb;
    float s = light.intensity * light.attenuation;
    s *= mi.NdotL;
    return color * s;
    return (color * light.color.rgb) *
            (light.intensity * light.attenuation * mi.NdotL);
}
#endif //__SURFACE_SHADING_SH__