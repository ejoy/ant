
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include <ibl/common.sh>

#ifndef THREADS
#define THREADS 8
#endif //THREADS

SAMPLERCUBE(s_source, 0);
IMAGE2D_ARRAY_WR(s_irradiance, rgba16f, 1);

vec4 irradiance_importance_sample(int sampleIndex, vec3 N)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 hp = hammersley2d(sampleIndex, u_sample_count);
    float u = hp.x;
    float v = hp.y;

    // generate the points on the hemisphere with a fitting mapping for
    
    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    float cos_thera = sqrt(1.0 - u);
    float sin_thera = sqrt(u); // equivalent to `sqrt(1.0 - cos_thera*cos_thera)`;
    float phi = 2.0 * MATH_PI * v;

    float cos_phi = cos(phi);
    float sin_phi = sin(phi);

    // sphere coordinate to XYZ
    vec3 dir_LS = normalize(vec3(sin_thera * cos_phi, sin_thera * sin_phi, cos_thera));
    mat3 TBN = generate_tbn(N);
    vec3 dir_WS = instMul(dir_LS, TBN);

    return vec4(dir_WS, cos_thera / MATH_PI);
}

NUM_THREADS(THREADS, THREADS, 1)
void main()
{
    vec4 color = vec4_splat(0.f);
    vec3 N = id2dir(gl_GlobalInvocationID, u_face_texture_size);

    for (uint sampleidx=0; sampleidx<u_sample_count; ++sampleidx){
        vec4 sample = irradiance_importance_sample(sampleidx, N);
        vec3 H = vec3(sample.xyz);
        float pdf = sample.w;

        // mipmap filtered samples (GPU Gems 3, 20.4)
        float lod = compute_lod(pdf);

        // apply the bias to the lod
        lod += u_lod_bias;

        float NdotH = clamp(dot(N, H), 0.0, 1.0);

        // sample lambertian at a lower resolution to avoid fireflies
        vec3 lambertian = textureCubeLod(s_source, H, lod).rgb;

        //// the below operations cancel each other out
        // lambertian *= NdotH; // lamberts law
        // lambertian /= pdf; // invert bias from importance sampling
        // lambertian /= MATH_PI; // convert irradiance to radiance https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/

        color += vec4(lambertian, 1.0);
    }

    imageStore(s_irradiance, gl_GlobalInvocationID, (MATH_PI * color) / u_sample_count);
}