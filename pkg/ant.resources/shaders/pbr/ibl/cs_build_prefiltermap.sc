#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include "pbr/ibl/common.sh"
#include "common/utils.sh"

SAMPLERCUBE(s_source, 0);

IMAGE2D_ARRAY_WO(s_prefilter_write, rgba16f, 1);

NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    ivec3 isize = imageSize(s_prefilter_write);
    if (any(gl_GlobalInvocationID.xy >= isize.xy))
        return;

    vec4 color = vec4_splat(0.0);
    vec3 N = id2dir(gl_GlobalInvocationID, vec2(isize.xy));

    for (int sampleidx=0; sampleidx < int(u_sample_count); ++sampleidx){
        vec4 H = importance_sample_GGX(sampleidx, N, u_roughness);
        vec3 H_dir = H.xyz;
        float pdf = H.w;
        float lod = compute_lod(pdf);
        lod += u_lod_bias;

        // Note: reflect takes incident vector.
        vec3 V = N;
        vec3 L = normalize(reflect(-V, H_dir));
        float NdotL = dot(N, L);

        if (NdotL > 0.0)
        {
            if(u_roughness == 0.0)
            {
                // without this the roughness=0 lod is too high (taken from original implementation)
                lod = u_lod_bias;
            }
            color += vec4(textureCubeLod(s_source, L, lod).rgb * NdotL, NdotL);
        }
    }

    imageStore(s_prefilter_write, gl_GlobalInvocationID, color / u_sample_count);
}