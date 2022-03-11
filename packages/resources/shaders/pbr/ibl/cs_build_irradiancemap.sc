
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include "common/sphere_coord.sh"
#include "pbr/ibl/common.sh"

#include "common/sphere_coord.sh"

SAMPLERCUBE(s_source, 0);

IMAGE2D_ARRAY_WR(s_irradiance, rgba32f, 1);

NUM_THREADS(WORKGROUP_THREADS, WORKGROUP_THREADS, 1)
void main()
{
    vec3 color = vec3_splat(0.0);
    vec3 N = id2dir(gl_GlobalInvocationID, u_face_texture_size);

    for (int sampleidx=0; sampleidx < int(u_sample_count); ++sampleidx){
        vec4 H = importance_sample_irradiance(sampleidx, N);
        vec3 H_dir = H.xyz;
        float pdf = H.w;

        float lod = compute_lod(pdf);
        lod += u_lod_bias;

        // sample lambertian at a lower resolution to avoid fireflies
        vec3 lambertian = textureCubeLod(s_source, H_dir, lod).rgb;

        //// the below operations cancel each other out
        // float NdotH = clamp(dot(N, H), 0.0, 1.0);
        // lambertian *= NdotH;     // lamberts law
        // lambertian /= pdf;       // invert bias from importance sampling
        // lambertian /= M_PI;   // convert irradiance to radiance https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/

        color += lambertian;
    }

    color /= u_sample_count;

    imageStore(s_irradiance, gl_GlobalInvocationID, vec4(color, 1.0));
}