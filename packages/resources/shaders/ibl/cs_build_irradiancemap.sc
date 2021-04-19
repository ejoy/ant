
#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

#include <ibl/common.sh>

#ifndef THREADS
#define THREADS 8
#endif //THREADS

SAMPLERCUBE(s_source, 0);
IMAGE2D_ARRAY_WR(s_irradiance, rgba16f, 1);

vec4 irradiance_importance_sample(int sampleIndex, vec3 N, float roughness)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 hammersleyPoint = hammersley2d(sampleIndex, u_sampleCount);
    float u = hammersleyPoint.x;
    float v = hammersleyPoint.y;

    // generate the points on the hemisphere with a fitting mapping for
    
    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    float cosTheta = sqrt(1.0 - u);
    float sinTheta = sqrt(u); // equivalent to `sqrt(1.0 - cosTheta*cosTheta)`;
    float phi = 2.0 * MATH_PI * v;

    float cosPhi = cos(phi);
    float sinPhi = sin(phi);

    float pdf = cosTheta / MATH_PI; // evaluation for solid angle, therefore drop the sinTheta

    // transform the hemisphere sample to the normal coordinate frame
    // i.e. rotate the hemisphere to the normal direction
    vec3 localSpaceDirection = normalize(vec3(sinTheta * cosPhi, sinTheta * sinPhi, cosTheta));
    mat3 TBN = generateTBN(N);
    vec3 direction = instMul(localSpaceDirection, TBN);

    return vec4(direction, pdf);
}

vec3 toN(uvec3 id)
{
    vec2 xy = id.xy * 2.0 - 1.0;
    xy.y *= -1.0;
    int faceidx = id.z;
    return normalize(uvToXYZ(faceidx, xy));
}

NUM_THREADS(THREADS, THREADS, 1)
void main()
{
    vec4 color = vec4_splat(0.f);
    vec3 N = toN(gl_GlobalInvocationID);
    for(int i = 0; i < u_sampleCount; ++i)
    {
        vec4 sample = irradiance_importance_sample(i, N, u_roughness);

        vec3 H = vec3(sample.xyz);
        float pdf = sample.w;

        // mipmap filtered samples (GPU Gems 3, 20.4)
        float lod = computeLod(pdf);

        // apply the bias to the lod
        lod += u_lodBias;

        float NdotH = clamp(dot(N, H), 0.0, 1.0);

        // sample lambertian at a lower resolution to avoid fireflies
        vec3 lambertian = textureCubeLod(s_source, H, lod).rgb;

        //// the below operations cancel each other out
        // lambertian *= NdotH; // lamberts law
        // lambertian /= pdf; // invert bias from importance sampling
        // lambertian /= MATH_PI; // convert irradiance to radiance https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/

        color += vec4(lambertian, 1.0);
    }

    imageStore(s_irradiance, gl_GlobalInvocationID, (MATH_PI * color) / u_sampleCount);
}