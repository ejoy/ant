$input v_texcoord0
#include <bgfx_shader.sh>
#include <shaderlib.sh>

#include "common/math.sh"

SAMPLER2D(s_sao, 0);

#if ENABLE_BENT_NORMAL
SAMPLER2D(s_bentnormal, 1);
#endif //ENABLE_BENT_NORMAL

uniform vec4 u_bilateral_kernels[2];
uniform vec4 u_bilateral_param;
#define u_step_offset   u_bilateral_param.xy
#define u_sample_count  u_bilateral_param.z
#define u_far_plane_over_edge_distance u_bilateral_param.w

float bilateralWeight(in highp float depth, in highp float sampleDepth) {
    float diff = (sampleDepth - depth) * u_far_plane_over_edge_distance;
    return max(0.0, 1.0 - diff * diff);
}

struct ao_info{
    float ao;
    float depth;
};

ao_info sampleAO(sampler2D texAO, vec2 uv) {
    vec3 data   = texture2D(texAO, uv).rgb;
    ao_info ai;
    ai.ao = data.r;
    ai.depth = unpackHalfFloat(data.gb);
    return ai;
}

vec3 sampleBN(sampler2D texBN, vec2 uv) {
    vec3 data = texture2D(texBN, uv).xyz;
    return decodeNormalUint(data);
}

float get_kernel_weight(uint idx)
{
    uint uidx = idx / 4;
    uint vidx = idx % 4;
    return u_bilateral_kernels[uidx][vidx];
}

struct sum_result{
    float ao;
    float weight;
#ifdef ENABLE_BENT_NORMAL
    vec3 bn;
#endif //ENABLE_BENT_NORMAL
};

void sum_all(vec2 uv, float center_depth, float weight, inout sum_result r)
{
    const ao_info s = sampleAO(s_sao, uv);
    const float bilateral = weight * bilateralWeight(center_depth, s.depth);
    r.ao += s.ao * bilateral;

#ifdef ENABLE_BENT_NORMAL
    vec3 bn = sampleBN(s_bentnormal, uv);
    r.bn += bn * bilateral;
#endif //ENABLE_BENT_NORMAL

    r.weight += bilateral;
}

void main()
{
    sum_result r;
    const ao_info center_ai = sampleAO(s_sao, v_texcoord0);
    r.weight = get_kernel_weight(0);
    r.ao = center_ai.ao * r.weight;

#if ENABLE_BENT_NORMAL
    r.bn = sampleBN(s_bentnormal, v_texcoord0) * r.weight;
#endif //ENABLE_BENT_NORMAL

    for (int i = 1; i < (int)u_sample_count; i++) {
        float weight = get_kernel_weight(i);
        vec2 offset = u_step_offset * i;
        sum_all(v_texcoord0 + offset, center_ai.depth, weight, r);
        sum_all(v_texcoord0 - offset, center_ai.depth, weight, r);
    }

    float ao = r.ao/r.weight;
    // simple dithering helps a lot (assumes 8 bits target)
    // this is most useful with high quality/large blurs
    ao += ((interleavedGradientNoise(gl_FragCoord.xy) - 0.5) / 255.0);

    gl_FragData[0] = vec4(ao, packHalfFloat(center_ai.depth), 1.0);

#if ENABLE_BENT_NORMAL
    gl_FragData[1] = packBentNormal(r.bn / r.weight);
#endif //ENABLE_BENT_NORMAL
}