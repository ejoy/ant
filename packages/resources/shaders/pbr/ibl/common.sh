// from: https://github.com/KhronosGroup/glTF-Sample-Viewer/blob/master/source/shaders/ibl_filtering.frag

uniform vec4 u_ibl_param;
#define u_sample_count      u_ibl_param.x
#define u_lod_bias          u_ibl_param.y
#define u_face_texture_size u_ibl_param.z
#define u_roughness         u_ibl_param.w

#ifndef WORKGROUP_THREADS
#define WORKGROUP_THREADS 8
#endif //WORKGROUP_THREADS

#include "pbr/pbr.sh"

vec3 uv2dir(int face, vec2 uv)
{
    switch (face){
    case 0:
        return vec3( 1.0, uv.y,-uv.x);
    case 1:
        return vec3(-1.0, uv.y, uv.x);
    case 2:
        return vec3( uv.x, 1.0,-uv.y);
    case 3:
        return vec3( uv.x,-1.0, uv.y);
    case 4:
        return vec3( uv.x, uv.y, 1.0);
    default:
        return vec3(-uv.x, uv.y,-1.0);
    }
}

vec2 dir2uv(vec3 dir)
{
    return vec2(
            0.5f + 0.5f * atan2(dir.z, dir.x) / M_PI,
            1.f - acos(dir.y) / M_PI);
}

vec3 id2dir(ivec3 id, float size)
{
    vec2 xy = id.xy / u_face_texture_size;
    xy = xy * 2.0 - 1.0;
    xy.y *= -1.0;
    int faceidx = id.z;
    return normalize(uv2dir(faceidx, xy));
}

mat3 generate_tbn(vec3 normal)
{
    vec3 bitangent = vec3(0.0, 1.0, 0.0);

    float NdotUp = dot(normal, vec3(0.0, 1.0, 0.0));
    float epsilon = 0.0000001;
    if (1.0 - abs(NdotUp) <= epsilon)
    {
        // Sampling +Y or -Y, so we need a more robust bitangent.
        bitangent = (NdotUp > 0.0) ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 0.0, -1.0);
    }

    vec3 tangent = normalize(cross(bitangent, normal));
    bitangent = cross(normal, tangent);

    return mtxFromCols(tangent, bitangent, normal);
}

vec3 spherecoord2dir(vec3 N, float sin_theta, float cos_theta, float sin_phi, float cos_phi)
{
    vec3 dir_LS = normalize(vec3(sin_theta * cos_phi, sin_theta * sin_phi, cos_theta));
    mat3 TBN = generate_tbn(N);
    return instMul(dir_LS, TBN);
}

// Mipmap Filtered Samples (GPU Gems 3, 20.4)
// https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-20-gpu-based-importance-sampling
float compute_lod(float pdf)
{
    // IBL Baker (Matt Davidson)
    // https://github.com/derkreature/IBLBaker/blob/65d244546d2e79dd8df18a28efdabcf1f2eb7717/data/shadersD3D11/IblImportanceSamplingDiffuse.fx#L215
    float solidAngleTexel = 4.0 * M_PI / (6.0 * float(u_face_texture_size) * float(u_sample_count));
    float solidAngleSample = 1.0 / (float(u_sample_count) * pdf);
    float lod = 0.5 * log2(solidAngleSample / solidAngleTexel);

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

float PDF_GGX(float NdotH, float roughness)
{
    float D = DistributionGGX(NdotH, roughness * roughness);
    return max(D / 4.0, 0.0);
}

vec3 importance_sample_GGX(int sampleidx, vec3 N, float roughness)
{
    vec2 hp2d = hammersley2d(sampleidx, u_sample_count);

    float alpha = roughness * roughness;
    float cos_theta = sqrt((1.0 - hp2d.x) / (1.0 + (alpha*alpha - 1.0) * hp2d.x));
    float sin_theta = sqrt(1.0 - cos_theta*cos_theta);
    float phi = 2.0 * M_PI * hp2d.y;
    float cos_phi = cos(phi);
    float sin_phi = sin(phi);

    return spherecoord2dir(N, sin_theta, cos_theta, sin_phi, cos_phi);
}

vec3 importance_sample_irradiance(int sampleidx, vec3 N)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 hp2d = hammersley2d(sampleidx, u_sample_count);
    // generate the points on the hemisphere with a fitting mapping for
    
    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    float cos_theta = sqrt(1.0 - hp2d.x);
    float sin_theta = sqrt(hp2d.x); // equivalent to `sqrt(1.0 - cos_theta*cos_theta)`;
    float phi = 2.0 * M_PI * hp2d.y;

    float cos_phi = cos(phi);
    float sin_phi = sin(phi);

    return spherecoord2dir(N, sin_theta, cos_theta, sin_phi, cos_phi);
}

float PDF_irradiance(float NdotH)
{
    return NdotH / M_PI;
}