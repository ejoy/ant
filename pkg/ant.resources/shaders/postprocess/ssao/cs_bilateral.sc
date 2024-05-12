$input v_texcoord0
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>

#include "common/utils.sh"
#include "common/math.sh"

#ifdef ENABLE_BENT_NORMAL
SAMPLER2DARRAY(s_ssao_result, 0);
IMAGE2D_ARRAY_WO(s_filter_result, rgba8, 1);
#else //!ENABLE_BENT_NORMAL
SAMPLER2D(s_ssao_result, 0);
IMAGE2D_WO(s_filter_result, rgba8, 1);
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

ao_info sampleAO(vec2 uv) {
#ifdef ENABLE_BENT_NORMAL
    // we can't use texture2DArray in compute shader, it will cause an error, use texture2DArrayLod instead
    vec3 data = texture2DArrayLod(s_ssao_result, vec3(uv, 0.0), 0.0).rgb;
#else //!ENABLE_BENT_NORMAL
    vec3 data = texture2DLod(s_ssao_result, uv, 0.0).rgb;
#endif //ENABLE_BENT_NORMAL

    ao_info ai;
    ai.ao = data.r;
    ai.depth = unpackHalfFloat(data.gb);
    return ai;
}

#ifdef ENABLE_BENT_NORMAL
vec3 sampleBN(vec2 uv) {
    // we can't use texture2DArray in compute shader, it will cause an error, use texture2DArrayLod instead
    vec3 data = texture2DArrayLod(s_ssao_result, vec3(uv, 1.0), 0.0).xyz;
    return decodeNormalUint(data);
}
#endif //ENABLE_BENT_NORMAL

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
    const ao_info s = sampleAO(uv);
    const float bilateral = weight * bilateralWeight(center_depth, s.depth);
    r.ao += s.ao * bilateral;

#ifdef ENABLE_BENT_NORMAL
    vec3 bn = sampleBN(uv);
    r.bn += bn * bilateral;
#endif //ENABLE_BENT_NORMAL

    r.weight += bilateral;
}

NUM_THREADS(16, 16, 1)
void main()
{
    const ivec2 uv_out = gl_GlobalInvocationID.xy;
#ifdef ENABLE_BENT_NORMAL
    const ivec2 size = imageSize(s_filter_result).xy;
#else //!ENABLE_BENT_NORMAL
    const ivec2 size = imageSize(s_filter_result);
#endif //ENABLE_BENT_NORMAL
    if (any(uv_out >= size))
        return;

    const vec2 uv = id2uv(uv_out, size);

    sum_result r;
    const ao_info center_ai = sampleAO(uv);
    r.weight = get_kernel_weight(0);
    r.ao = center_ai.ao * r.weight;

#ifdef ENABLE_BENT_NORMAL
    r.bn = sampleBN(uv) * r.weight;
#endif //ENABLE_BENT_NORMAL

    for (int i = 1; i < (int)u_sample_count; i++) {
        float weight = get_kernel_weight(i);
        vec2 offset = u_step_offset * i;
        sum_all(uv + offset, center_ai.depth, weight, r);
        sum_all(uv - offset, center_ai.depth, weight, r);
    }

    float ao = r.ao/r.weight;
    // simple dithering helps a lot (assumes 8 bits target)
    // this is most useful with high quality/large blurs
    ao += ((interleavedGradientNoise(uv_out.xy) - 0.5) / 255.0);

#ifdef ENABLE_BENT_NORMAL
    imageStore(s_filter_result, ivec3(uv_out, 0), vec4(vec3(ao, packHalfFloat(center_ai.depth)), 0.0));
    imageStore(s_filter_result, ivec3(uv_out, 1), vec4(encodeNormalUint(r.bn/r.weight), 0.0));
#else //!ENABLE_BENT_NORMAL
    imageStore(s_filter_result, uv_out, vec4(vec3(ao, packHalfFloat(center_ai.depth)), 0.0));
#endif //ENABLE_BENT_NORMAL
}