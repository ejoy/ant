// from: https://github.com/KhronosGroup/glTF-Sample-Viewer/blob/master/source/shaders/ibl_filtering.frag

uniform vec4 u_build_ibl_param;
#define u_sample_count      u_build_ibl_param.x
#define u_lod_bias          u_build_ibl_param.y
#define u_cubemap_facesize  u_build_ibl_param.z
#define u_roughness         u_build_ibl_param.w

#ifndef WORKGROUP_THREADS
#define WORKGROUP_THREADS 8
#endif //WORKGROUP_THREADS

#include "pbr/common.sh"

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

    float lod = 0.5 * log2( 6.0 * float(u_cubemap_facesize) * float(u_cubemap_facesize) / (float(u_sample_count) * pdf));

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

struct MicrofacetDistributionSample
{
    float pdf;
    float cos_theta;
    float sin_theta;
    float phi;
};

vec3 sample2dir(MicrofacetDistributionSample sample)
{
    float cos_phi = cos(sample.phi), sin_phi = sin(sample.phi);
    return normalize(vec3(
        sample.sin_theta * cos_phi,
        sample.sin_theta * sin_phi,
        sample.cos_theta));
}

vec3 tangent2world(vec3 dir_TS, vec3 normal_WS)
{
    vec3 T, B;
    calc_TB(normal_WS, T, B);
    return transform_TBN(dir_TS, T, B, normal_WS);
}

float D_GGX(float NdotH, float roughness) {
    float a = NdotH * roughness;
    float k = roughness / max(1.0 - NdotH * NdotH + a * a, 1e-6);
    return k * k * (1.0 / M_PI);
}

// GGX microfacet distribution
// https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.html
// This implementation is based on https://bruop.github.io/ibl/,
//  https://www.tobias-franke.eu/log/2014/03/30/notes_on_importance_sampling.html
// and https://developer.nvidia.com/gpugems/GPUGems3/gpugems3_ch20.html
MicrofacetDistributionSample GGX(vec2 xi, float roughness)
{
    MicrofacetDistributionSample ggx;

    // evaluate sampling equations
    float alpha = roughness * roughness;
    ggx.cos_theta = saturate(sqrt((1.0 - xi.y) / (1.0 + (alpha * alpha - 1.0) * xi.y)));
    ggx.sin_theta = sqrt(1.0 - ggx.cos_theta * ggx.cos_theta);
    ggx.phi = 2.0 * M_PI * xi.x;

    // evaluate GGX pdf (for half vector)
    ggx.pdf = D_GGX(ggx.cos_theta, alpha);

    // Apply the Jacobian to obtain a pdf that is parameterized by l
    // see https://bruop.github.io/ibl/
    // Typically you'd have the following:
    // float pdf = D_GGX(NoH, roughness) * NoH / (4.0 * VoH);
    // but since V = N => VoH == NoH
    ggx.pdf /= 4.0;

    return ggx;
}

vec4 importance_sample_GGX(int sampleidx, vec3 N, float roughness)
{
    vec2 xi = hammersley2d(sampleidx, u_sample_count);
    MicrofacetDistributionSample sample = GGX(xi, roughness);
    return vec4(tangent2world(sample2dir(sample), N), sample.pdf);
}

MicrofacetDistributionSample Lambertian(vec2 xi)
{
    MicrofacetDistributionSample lambertian;

    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    lambertian.cos_theta = sqrt(1.0 - xi.y);
    lambertian.sin_theta = sqrt(xi.y); // equivalent to `sqrt(1.0 - cos_theta*cos_theta)`;
    lambertian.phi = 2.0 * M_PI * xi.x;

    lambertian.pdf = lambertian.cos_theta / M_PI; // evaluation for solid angle, therefore drop the sin_theta

    return lambertian;
}

vec4 importance_sample_Lambertian(int sampleidx, vec3 N)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 xi = hammersley2d(sampleidx, u_sample_count);
    // generate the points on the hemisphere with a fitting mapping for
    
    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    MicrofacetDistributionSample sample = Lambertian(xi);
    return vec4(tangent2world(sample2dir(sample), N), sample.pdf);
}