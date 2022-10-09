$input v_texcoord0
#include <bgfx_shader.sh>
#include <shaderlib.sh>

#include "postprocess/ssao/util.sh"

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

void main()
{
    vec3 data = texture2D(s_sao, v_texcoord0).rgb;

    //TODO: need check this is correct for our skybox code
    if (data.g * data.b == 1.0) {
        // This is the skybox, skip
        gl_FragData[0] = vec4(data, 1.0);
#if ENABLE_BENT_NORMAL
        gl_FragData[1] = vec4(0.0, 0.0, 0.0, 1.0);
#endif //ENABLE_BENT_NORMAL
        return;
    }

    // we handle the center pixel separately because it doesn't participate in
    // bilateral filtering
    float total_weight = get_kernel_weight(0);

    const ao_info center_ai = {data.r, unpackHalfFloat(data.gb)};
    float sumAO = center_ai.ao * total_weight;

#if ENABLE_BENT_NORMAL
    vec3 bn = sampleBN(s_bentnormal, v_texcoord0);
    vec3 sumBN  = bn * total_weight;
#endif //ENABLE_BENT_NORMAL

    vec2 offset = u_step_offset;
    for (int i = 1; i < (int)u_sample_count; i++) {
        float weight = get_kernel_weight(i);
        vec2 offsets[2] = {offset, -offset};

        for (int iuv=0; iuv<2; ++iuv){
            vec2 uv = v_texcoord0 + offsets[iuv];
            const ao_info s = sampleAO(s_sao, uv);
            const float bilateral = weight * bilateralWeight(center_ai.depth, s.depth);
            sumAO += s.ao * bilateral;

#if ENABLE_BENT_NORMAL
            bn = sampleBN(s_bentnormal, uv);
            sumBN += bn * bilateral;
#endif //ENABLE_BENT_NORMAL

            total_weight += bilateral;
        }
        offset += u_step_offset;
    }

    float ao = sumAO * (1.0 / total_weight);
    // simple dithering helps a lot (assumes 8 bits target)
    // this is most useful with high quality/large blurs
    ao += ((interleavedGradientNoise(gl_FragCoord.xy) - 0.5) / 255.0);

    gl_FragData[0] = vec4(ao, data.gb, 1.0);

#if ENABLE_BENT_NORMAL
    bn = sumBN * (1.0 / total_weight);
    gl_FragData[1] = packBentNormal(bn);
#endif //ENABLE_BENT_NORMAL
}