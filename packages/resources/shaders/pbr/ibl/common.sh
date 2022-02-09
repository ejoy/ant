// from: https://github.com/KhronosGroup/glTF-Sample-Viewer/blob/master/source/shaders/ibl_filtering.frag

uniform vec4 u_build_ibl_param;
#define u_sample_count      u_build_ibl_param.x
#define u_lod_bias          u_build_ibl_param.y
#define u_face_texture_size u_build_ibl_param.z
#define u_roughness         u_build_ibl_param.w

#ifndef WORKGROUP_THREADS
#define WORKGROUP_THREADS 8
#endif //WORKGROUP_THREADS

#include "pbr/pbr.sh"
#include "common/common.sh"

vec3 id2dir(ivec3 id, float size)
{
    vec2 uv = id.xy / u_face_texture_size;
    uv = vec2(uv.x, 1.0-uv.y) * 2.0 - 1.0;
    int faceidx = id.z;
    return normalize(uvface2dir(uv, faceidx));
}

void calc_TB(vec3 N, out vec3 T, out vec3 B)
{
    float epsilon = 0.0000001;
    T = cross(N, vec3(0.0, 1.0, 0.0));
	T = lerp(cross(N, vec3(1.0, 0.0, 0.0)), T, step(epsilon, dot(T, T)));

	T = normalize(T);
	B = normalize(cross(N, T));
}

vec3 transform_TBN(vec3 v, vec3 T, vec3 B, vec3 N)
{
    //careful here for using mat3 build by T, B, N in different platform, so just multipy v with T, B, N can skip this platform relate issue
    return T*v.x + B*v.y + N*v.z;
}

vec3 spherecoord2dir(vec3 N, float sin_theta, float cos_theta, float sin_phi, float cos_phi)
{
    vec3 dir_LS = normalize(vec3(sin_theta * cos_phi, sin_theta * sin_phi, cos_theta));
    vec3 T, B;
    calc_TB(N, T, B);
    return transform_TBN(dir_LS, T, B, N);
}

// Mipmap Filtered Samples (GPU Gems 3, 20.4)
// https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-20-gpu-based-importance-sampling
float compute_lod(float pdf)
{
    // // IBL Baker (Matt Davidson)
    // // https://github.com/derkreature/IBLBaker/blob/65d244546d2e79dd8df18a28efdabcf1f2eb7717/data/shadersD3D11/IblImportanceSamplingDiffuse.fx#L215
    // float solidAngleTexel = 4.0 * M_PI / (6.0 * float(u_face_texture_size) * float(u_sample_count));
    // float solidAngleSample = 1.0 / (float(u_sample_count) * pdf);
    // float lod = 0.5 * log2(solidAngleSample / solidAngleTexel);

    // // Solid angle of current sample -- bigger for less likely samples
    // float omegaS = 1.0 / (float(u_sampleCount) * pdf);
    // // Solid angle of texel
    // // note: the factor of 4.0 * MATH_PI 
    // float omegaP = 4.0 * MATH_PI / (6.0 * float(u_width) * float(u_width));
    // // Mip level is determined by the ratio of our sample's solid angle to a texel's solid angle 
    // // note that 0.5 * log2 is equivalent to log4
    // float lod = 0.5 * log2(omegaS / omegaP);

    // babylon introduces a factor of K (=4) to the solid angle ratio
    // this helps to avoid undersampling the environment map
    // this does not appear in the original formulation by Jaroslav Krivanek and Mark Colbert
    // log4(4) == 1
    // lod += 1.0;

    // We achieved good results by using the original formulation from Krivanek & Colbert adapted to cubemaps

    // https://cgg.mff.cuni.cz/~jaroslav/papers/2007-sketch-fis/Final_sap_0073.pdf

    float lod = 0.5 * log2( 6.0 * float(u_face_texture_size) * float(u_face_texture_size) / (float(u_sample_count) * pdf));

    return lod;
}

// Hammersley Points on the Hemisphere
// CC BY 3.0 (Holger Dammertz)
// http://holger.dammertz.org/stuff/notes_HammersleyOnHemisphere.html
// with adapted interface
float radicalInverse_VdC(uint bits)
{
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    return float(bits) * 2.3283064365386963e-10; // / 0x100000000
}

// hammersley2d describes a sequence of points in the 2d unit square [0,1)^2
// that can be used for quasi Monte Carlo integration
vec2 hammersley2d(int i, int N)
{
    return vec2(float(i)/float(N), radicalInverse_VdC(uint(i)));
}

//NOTICE: this D_GGX is not the same as pbr.sh D_GGX, that is more complexity
float D_GGX_ibl(float NdotH, float roughness) {
    float a = NdotH * roughness;
    float k = roughness / (1.0 - NdotH * NdotH + a * a);
    return k * k * (1.0 / M_PI);
}

vec4 importance_sample_GGX(int sampleidx, vec3 N, float roughness)
{
    vec2 hp2d = hammersley2d(sampleidx, u_sample_count);

    float alpha = roughness * roughness;
    float cos_theta = saturate(sqrt((1.0 - hp2d.y) / (1.0 + (alpha*alpha - 1.0) * hp2d.y)));
    float sin_theta = sqrt(1.0 - cos_theta*cos_theta);
    float phi = 2.0 * M_PI * hp2d.x;
    float cos_phi = cos(phi);
    float sin_phi = sin(phi);

    float pdf = D_GGX_ibl(cos_theta, alpha) / 4.0;

    vec3 dir = spherecoord2dir(N, sin_theta, cos_theta, sin_phi, cos_phi);
    return vec4(dir, pdf);
}

vec4 importance_sample_irradiance(int sampleidx, vec3 N)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 hp2d = hammersley2d(sampleidx, u_sample_count);
    // generate the points on the hemisphere with a fitting mapping for
    
    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    float cos_theta = sqrt(1.0 - hp2d.y);
    float sin_theta = sqrt(hp2d.y); // equivalent to `sqrt(1.0 - cos_theta*cos_theta)`;
    float phi = 2.0 * M_PI * hp2d.x;

    float cos_phi = cos(phi);
    float sin_phi = sin(phi);

    vec3 dir = spherecoord2dir(N, sin_theta, cos_theta, sin_phi, cos_phi);
    float pdf = cos_theta / M_PI;
    return vec4(dir, pdf);
}