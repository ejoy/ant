
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

#if defined(MATERIAL_HAS_ANISOTROPY)
vec3 anisotropicLobe(const material_info mi, const light_info light, const vec3 h,
        float NoV, float NoL, float NoH, float LoH) {

    vec3 l = light.l;
    vec3 t = mi.anisotropicT;
    vec3 b = mi.anisotropicB;
    vec3 v = shading_view;

    float ToV = dot(t, v);
    float BoV = dot(b, v);
    float ToL = dot(t, l);
    float BoL = dot(b, l);
    float ToH = dot(t, h);
    float BoH = dot(b, h);

    // Anisotropic parameters: at and ab are the roughness along the tangent and bitangent
    // to simplify materials, we derive them from a single roughness parameter
    // Kulla 2017, "Revisiting Physically Based Shading at Imageworks"
    float at = max(mi.roughness * (1.0 + mi.anisotropy), MIN_ROUGHNESS);
    float ab = max(mi.roughness * (1.0 - mi.anisotropy), MIN_ROUGHNESS);

    // specular anisotropic BRDF
    float D = distributionAnisotropic(at, ab, ToH, BoH, NoH);
    float V = visibilityAnisotropic(pixel.roughness, at, ab, ToV, BoV, ToL, BoL, NoV, NoL);
    vec3  F = fresnel(pixel.f0, LoH);

    return (D * V) * F;
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
#if defined(MATERIAL_HAS_ANISOTROPY)
    return anisotropicLobe(mi, light, h, NoV, NoL, NoH, LoH);
#else
    return isotropicLobe(mi, h, NoV, NoL, NoH, LoH);
#endif
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
#if defined(MATERIAL_HAS_REFRACTION)
    Fd *= (1.0 - mi.transmission);
#endif

    // TODO: attenuate the diffuse lobe to avoid energy gain

    // The energy compensation term is used to counteract the darkening effect
    // at high roughness
    float energyCompensation = 1.0;//mi.energyCompensation;
    vec3 color = Fd + Fr * energyCompensation;

#if defined(MATERIAL_HAS_SHEEN_COLOR)
    color *= mi.sheenScaling;
    color += sheenLobe(mi, NoV, NoL, NoH);
#endif

#if defined(MATERIAL_HAS_CLEAR_COAT)
    float Fcc;
    float clearCoat = clearCoatLobe(mi, h, NoH, LoH, Fcc);
    float attenuation = 1.0 - Fcc;

#if defined(MATERIAL_HAS_NORMAL) || defined(MATERIAL_HAS_CLEAR_COAT_NORMAL)
    color *= attenuation * NoL;

    // If the material has a normal map, we want to use the geometric normal
    // instead to avoid applying the normal map details to the clear coat layer
    float clearCoatNoL = saturate(dot(shading_clearCoatNormal, light.l));
    color += clearCoat * clearCoatNoL;

    // Early exit to avoid the extra multiplication by NoL
    return (color * light.colorIntensity.rgb) *
            (light.colorIntensity.w * light.attenuation);
#else
    color *= attenuation;
    color += clearCoat;
#endif
#endif

    return (color * light.color.rgb) *
            (light.intensity * light.attenuation * NoL);
}