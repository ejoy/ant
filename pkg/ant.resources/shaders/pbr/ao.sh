#ifndef _AO_SH_
#define _AO_SH_

#include "common/math.sh"

#ifdef ENABLE_BENT_NORMAL
SAMPLER2DARRAY(s_ssao, 9);
#else //!ENABLE_BENT_NORMAL
SAMPLER2D(s_ssao, 9);
#endif //ENABLE_BENT_NORMAL

float SpecularAO_Lagarde(float NoV, float visibility, float roughness) {
    // Lagarde and de Rousiers 2014, "Moving Frostbite to PBR"
    return saturate(pow(NoV + visibility, exp2(-16.0 * roughness - 1.0)) - 1.0 + visibility);
}

float sphericalCapsIntersection(float cosCap1, float cosCap2, float cosDistance) {
    // Oat and Sander 2007, "Ambient Aperture Lighting"
    // Approximation mentioned by Jimenez et al. 2016
    float r1 = acosFastPositive(cosCap1);
    float r2 = acosFastPositive(cosCap2);
    float d  = acosFast(cosDistance);

    // We work with cosine angles, replace the original paper's use of
    // cos(min(r1, r2)) with max(cosCap1, cosCap2)
    // We also remove a multiplication by 2 * PI to simplify the computation
    // since we divide by 2 * PI in computeBentSpecularAO()

    if (min(r1, r2) <= max(r1, r2) - d) {
        return 1.0 - max(cosCap1, cosCap2);
    } else if (r1 + r2 <= d) {
        return 0.0;
    }

    float delta = abs(r1 - r2);
    float x = 1.0 - saturate((d - delta) / max(r1 + r2 - delta, 1e-4));
    // simplified smoothstep()
    float area = sq(x) * (-2.0 * x + 3.0);
    return area * (1.0 - max(cosCap1, cosCap2));
}

// This function could (should?) be implemented as a 3D LUT instead, but we need to save samplers
float SpecularAO_Cones(vec3 bentNormal, vec3 reflect_vector, float visibility, float roughness) {
    // Jimenez et al. 2016, "Practical Realtime Strategies for Accurate Indirect Occlusion"

    // aperture from ambient occlusion
    float cosAv = sqrt(1.0 - visibility);
    // aperture from roughness, log(10) / log(2) = 3.321928
    float cosAs = exp2(-3.321928 * sq(roughness));
    // angle between bent normal and reflection direction
    float cosB  = dot(bentNormal, reflect_vector);

    // Remove the 2 * PI term from the denominator, it cancels out the same term from
    // sphericalCapsIntersection()
    float ao = sphericalCapsIntersection(cosAv, cosAs, cosB) / (1.0 - cosAs);
    // Smoothly kill specular AO when entering the perceptual roughness range [0.1..0.3]
    // Without this, specular AO can remove all reflections, which looks bad on metals
    return mix(1.0, ao, smoothstep(0.01, 0.09, roughness));
}

#ifdef ENABLE_BENT_NORMAL
vec3 fetch_bent_normal(vec2 uv, vec4 weights)
{
    const gather_result3 r = texture_gather3(s_ssao, vec3(uv, 1.0));

    const vec3 bn = vec3(
        dot(r.r, weights),
        dot(r.g, weights),
        dot(r.b, weights));
    return normalize(decodeNormalUint(bn));
}
#endif //ENABLE_BENT_NORMAL

float unpack(vec2 depth) {
    // this is equivalent to (x8 * 256 + y8) / 65535, which gives a value between 0 and 1
    return (depth.x * (256.0 / 257.0) + depth.y * (1.0 / 257.0));
}

struct ao_value
{
    float ao;
    vec4 weights;
};

ao_value fetch_ao(vec2 uv, float depthVS)
{
    ao_value av;
#ifdef HIGH_QULITY_SPECULAR_AO
#ifdef ENABLE_BENT_NORMAL
    gather_result3 r = texture_gather3(s_ssao, vec3(uv, 0.0));
#else //!ENABLE_BENT_NORMAL
    gather_result3 r = texture_gather3(s_ssao, uv);
#endif //ENABLE_BENT_NORMAL
    
    // bilateral weights
    vec4 depthsVS = vec4(
        unpack(vec2(r.g.x, r.b.x)),
        unpack(vec2(r.g.y, r.b.y)),
        unpack(vec2(r.g.z, r.b.z)),
        unpack(vec2(r.g.w, r.b.w)));
    depthsVS *= u_far;

    // bilinear weights
    const vec2 f = fract(uv * u_ssao_size - 0.5);
    const vec4 b = vec4(
        (1.0 - f.x) * f.y,
        f.x * f.y,
        f.x * (1.0 - f.y),
        (1.0 - f.x) * (1.0 - f.y));

    vec4 w = (vec4_splat(depthVS) - depthsVS) * u_ssao_edge_distance;
    w = max(vec4_splat(MEDIUMP_FLT_MIN), 1.0 - w * w) * b;

    
    av.weights = w / (w.x + w.y + w.z + w.w);
    //r.r is ao value
    av.ao = dot(r.r, av.weights);
#else   //!HIGH_QULITY_SPECULAR_AO
#ifdef ENABLE_BENT_NORMAL
    av.ao = texture2DArray(s_ssao, vec3(uv, 0.0)).r;
#else //!ENABLE_BENT_NORMAL
    av.ao = texture2D(s_ssao, uv).r;
#endif //ENABLE_BENT_NORMAL
    
    av.weights = vec4_splat(0.0);
#endif  //HIGH_QULITY_SPECULAR_AO
    return av;
}

float calc_specularAO(in material_info mi, ao_value av)
{
#ifdef HIGH_QULITY_SPECULAR_AO
    float specularAO = SpecularAO_Cones(mi.bent_normal, mi.reflect_vector, av.ao, mi.roughness);

#   ifdef ENABLE_BENT_NORMAL
    vec3 bn = fetch_bent_normal(mi.screen_uv, av.weights);
    float ssSpecularAO = SpecularAO_Cones(bn, mi.reflect_vector, av.ao, mi.roughness);
    // Combine the specular AO from the texture with screen space specular AO
    specularAO = min(specularAO, ssSpecularAO);
#   endif //ENABLE_BENT_NORMAL
    return specularAO;
#else //HIGH_QULITY_SPECULAR_AO
    return SpecularAO_Lagarde(mi.NdotV, av.ao, mi.roughness);
#endif //HIGH_QULITY_SPECULAR_AO
}

void apply_occlusion(in material_info mi, inout vec3 indirect_diffuse, inout vec3 indirect_specular)
{
    ao_value av = fetch_ao(mi.screen_uv, mi.distanceVS);
    av.ao = min(av.ao, mi.occlusion);

    indirect_diffuse *= av.ao;
    indirect_specular *= calc_specularAO(mi, av);
}

#endif //_AO_SH_
