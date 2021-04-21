#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include <ibl/common.sh>

#ifndef WORKGROUP_THREADS
#define WORKGROUP_THREADS 8
#endif //WORKGROUP_THREADS

SAMPLERCUBE(s_source, 0);
IMAGE2D_ARRAY_WR(s_prefilter, rgba16f, 1);

NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    vec4 color = vec4_splat(0.f);
    vec3 N = id2dir(gl_GlobalInvocationID, u_face_texture_size);

    for (uint sampleidx=0; sampleidx<u_sample_count; ++sampleidx){
        vec3 H = importance_sample_GGX(sampleidx, N, u_roughness);
        float NdotH = saturate(H.z);
        float pdf = PDF_GGX(NdotH, u_roughness);

        float lod = compute_lod(pdf);
        lod += u_lod_bias;

        // Note: reflect takes incident vector.
        vec3 V = N;
        vec3 L = normalize(reflect(-V, H));
        float NdotL = dot(N, L);

        if (NdotL > 0.0)
        {
            if(u_roughness == 0.0)
            {
                // without this the roughness=0 lod is too high (taken from original implementation)
                lod = u_lod_bias;
            }

            color += vec4(textureLod(s_source, L, lod).rgb * NdotL, NdotL);
        }
    }

    imageStore(s_prefilter, gl_GlobalInvocationID, color / u_sample_count);
}