#ifndef __SURFACE_SHADING_SH__
#define __SURFACE_SHADING_SH__

#include "brdf.sh"

#if defined(MATERIAL_HAS_SHEEN_COLOR)
vec3 sheenLobe(const material_info mi, float NoV, float NoL, float NoH) {
    float D = distributionCloth(mi.sheenRoughness, NoH);
    float V = visibilityCloth(NoV, NoL);

    return (D * V) * mi.sheenColor;
}
#endif

#if defined(MATERIAL_HAS_CLEAR_COAT)
float clearCoatLobe(const material_info mi, const vec3 h, float NoH, float LoH, out float Fcc) {
#if defined(MATERIAL_HAS_NORMAL) || defined(MATERIAL_HAS_CLEAR_COAT_NORMAL)
    // If the material has a normal map, we want to use the geometric normal
    // instead to avoid applying the normal map details to the clear coat layer
    float clearCoatNoH = saturate(dot(shading_clearCoatNormal, h));
#else
    float clearCoatNoH = NoH;
#endif

    // clear coat specular lobe
    float D = distributionClearCoat(mi.clearCoatRoughness, clearCoatNoH, h);
    float V = visibilityClearCoat(LoH);
    float F = F_Schlick(0.04, 1.0, LoH) * mi.clearCoat; // fix IOR to 1.5

    Fcc = F;
    return D * V * F;
}
#endif

vec3 isotropicLobe(const material_info mi, const vec3 h,
        float NoV, float NoL, float NoH, float LoH) {

    float D = distribution(mi.roughness, NoH, h);
    float V = visibility(mi.roughness, NoV, NoL);
    vec3  F = fresnel(mi.f0, LoH);

    return (D * V) * F;
}

vec3 specularLobe(const material_info mi, const light_info light, const vec3 h,
        float NoV, float NoL, float NoH, float LoH) {
    return isotropicLobe(mi, h, NoV, NoL, NoH, LoH);
}

vec3 diffuseLobe(const material_info mi, float NoV, float NoL, float LoH) {
    return mi.albedo * diffuse(mi.roughness, NoV, NoL, LoH);
}

/**
 * Evaluates lit materials with the standard shading model. This model comprises
 * of 2 BRDFs: an optional clear coat BRDF, and a regular surface BRDF.
 *
 * Surface BRDF
 * The surface BRDF uses a diffuse lobe and a specular lobe to render both
 * dielectrics and conductors. The specular lobe is based on the Cook-Torrance
 * micro-facet model (see brdf.fs for more details). In addition, the specular
 * can be either isotropic or anisotropic.
 *
 * Clear coat BRDF
 * The clear coat BRDF simulates a transparent, absorbing dielectric layer on
 * top of the surface. Its IOR is set to 1.5 (polyutherane) to simplify
 * our computations. This BRDF only contains a specular lobe and while based
 * on the Cook-Torrance microfacet model, it uses cheaper terms than the surface
 * BRDF's specular lobe (see brdf.fs).
 */
vec3 surfaceShading(const material_info mi, const light_info light) {
    vec3 h = normalize(mi.V + light.pt2l);

    float NoV = mi.NdotV;
    float NoL = mi.NdotL;
    float NoH = saturate(dot(mi.N, h));
    float LoH = saturate(dot(light.pt2l, h));

    vec3 Fr = specularLobe(mi, light, h, NoV, NoL, NoH, LoH);
    vec3 Fd = diffuseLobe(mi, NoV, NoL, LoH);

    // TODO: attenuate the diffuse lobe to avoid energy gain

    // The energy compensation term is used to counteract the darkening effect
    // at high roughness
    float energyCompensation = 1.0;//mi.energyCompensation;
    vec3 color = Fd + Fr * energyCompensation;

    return (color * light.color.rgb) *
            (light.intensity * light.attenuation * NoL);
}
#endif //__SURFACE_SHADING_SH__