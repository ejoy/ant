$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/sphere_coord.sh"

// enum
#define cLambertian 0
#define cGGX        1
#define cCharlie    2


//layout(push_constant) uniform FilterParameters {
uniform vec4 u_ibl_params;
#define u_roughness     u_ibl_params.x
#define u_sampleCount   u_ibl_params.y
#define u_width         u_ibl_params.z
#define u_lodBias       u_ibl_params.w

uniform vec4 u_ibl_params1;
#define u_distribution  u_ibl_params1.x
#define u_currentFace   u_ibl_params1.y
#define u_isGeneratingLUT u_ibl_params1.z

// uniform  float u_roughness;
// uniform  int u_sampleCount;
// uniform  int u_width;
// uniform  float u_lodBias;
// uniform  int u_distribution; // enum
// uniform int u_currentFace;
// uniform int u_isGeneratingLUT;

SAMPLER2D(s_panorama, 0);

vec4 sample_source(vec3 dir, float lod)
{
    vec2 uv = dir2spherecoord(dir);
    return texture2DLod(s_panorama, uv, lod);
}

vec3 get_sample_vec(int face, vec2 uv)
{
    switch(face){
        case 0: return vec3(  1.0,  uv.y,-uv.x);
        case 1: return vec3( -1.0,  uv.y, uv.x);
        case 2: return vec3( uv.x,   1.0,-uv.y);
        case 3: return vec3( uv.x,  -1.0,  uv.y);
        case 4: return vec3( uv.x,  uv.y,  1.0);
        default: return vec3(-uv.x,  uv.y, -1.0);
    }
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
vec2 hammersley2d(int i, int N) {
    return vec2(float(i)/float(N), radicalInverse_VdC(uint(i)));
}

// Hemisphere Sample

// TBN generates a tangent bitangent normal coordinate frame from the normal
// (the normal must be normalized)
// mat3 generateTBN(vec3 normal)
// {
//     vec3 bitangent = vec3(0.0, 1.0, 0.0);

//     float NdotUp = dot(normal, vec3(0.0, 1.0, 0.0));
//     float epsilon = 0.0000001;
//     if (1.0 - abs(NdotUp) <= epsilon)
//     {
//         // Sampling +Y or -Y, so we need a more robust bitangent.
//         if (NdotUp > 0.0)
//         {
//             bitangent = vec3(0.0, 0.0, 1.0);
//         }
//         else
//         {
//             bitangent = vec3(0.0, 0.0, -1.0);
//         }
//     }

//     vec3 tangent = normalize(cross(bitangent, normal));
//     bitangent = cross(normal, tangent);

//     return mat3(tangent, bitangent, normal);
// }

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

vec3 transformDirection(vec3 N, vec3 dir)
{
    vec3 T, B;
    calc_TB(N, T, B);
    return transform_TBN(dir, T, B, N);
}

struct MicrofacetDistributionSample
{
    float pdf;
    float cosTheta;
    float sinTheta;
    float phi;
};

float D_GGX(float NdotH, float roughness) {
    float a = NdotH * roughness;
    float k = roughness / (1.0 - NdotH * NdotH + a * a);
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
    ggx.cosTheta = saturate(sqrt((1.0 - xi.y) / (1.0 + (alpha * alpha - 1.0) * xi.y)));
    ggx.sinTheta = sqrt(1.0 - ggx.cosTheta * ggx.cosTheta);
    ggx.phi = 2.0 * M_PI * xi.x;

    // evaluate GGX pdf (for half vector)
    ggx.pdf = D_GGX(ggx.cosTheta, alpha);

    // Apply the Jacobian to obtain a pdf that is parameterized by l
    // see https://bruop.github.io/ibl/
    // Typically you'd have the following:
    // float pdf = D_GGX(NoH, roughness) * NoH / (4.0 * VoH);
    // but since V = N => VoH == NoH
    ggx.pdf /= 4.0;

    return ggx;
}

MicrofacetDistributionSample Lambertian(vec2 xi, float roughness)
{
    MicrofacetDistributionSample lambertian;

    // Cosine weighted hemisphere sampling
    // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
    lambertian.cosTheta = sqrt(1.0 - xi.y);
    lambertian.sinTheta = sqrt(xi.y); // equivalent to `sqrt(1.0 - cosTheta*cosTheta)`;
    lambertian.phi = 2.0 * M_PI * xi.x;

    lambertian.pdf = lambertian.cosTheta / M_PI; // evaluation for solid angle, therefore drop the sinTheta

    return lambertian;
}


// getImportanceSample returns an importance sample direction with pdf in the .w component
vec4 getImportanceSample(int sampleIndex, vec3 N, float roughness)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 xi = hammersley2d(sampleIndex, u_sampleCount);

    MicrofacetDistributionSample importanceSample;

    // generate the points on the hemisphere with a fitting mapping for
    // the distribution (e.g. lambertian uses a cosine importance)
    if(u_distribution == cLambertian)
    {
        importanceSample = Lambertian(xi, roughness);
    }
    else if(u_distribution == cGGX)
    {
        // Trowbridge-Reitz / GGX microfacet model (Walter et al)
        // https://www.cs.cornell.edu/~srm/publications/EGSR07-btdf.html
        importanceSample = GGX(xi, roughness);
    }
    else if(u_distribution == cCharlie)
    {
        //importanceSample = Charlie(xi, roughness);
    }

    // transform the hemisphere sample to the normal coordinate frame
    // i.e. rotate the hemisphere to the normal direction
    vec3 localSpaceDirection = normalize(vec3(
        importanceSample.sinTheta * cos(importanceSample.phi), 
        importanceSample.sinTheta * sin(importanceSample.phi), 
        importanceSample.cosTheta
    ));
    // mat3 TBN = generateTBN(N);
    // vec3 direction = TBN * localSpaceDirection;

    vec3 direction = transformDirection(N, localSpaceDirection);
    return vec4(direction, importanceSample.pdf);
}

// Mipmap Filtered Samples (GPU Gems 3, 20.4)
// https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-20-gpu-based-importance-sampling
// https://cgg.mff.cuni.cz/~jaroslav/papers/2007-sketch-fis/Final_sap_0073.pdf
float computeLod(float pdf)
{
    // // Solid angle of current sample -- bigger for less likely samples
    // float omegaS = 1.0 / (float(u_sampleCount) * pdf);
    // // Solid angle of texel
    // // note: the factor of 4.0 * M_PI 
    // float omegaP = 4.0 * M_PI / (6.0 * float(u_width) * float(u_width));
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
    float lod = 0.5 * log2( 6.0 * float(u_width) * float(u_width) / (float(u_sampleCount) * pdf));


    return lod;
}

vec3 filterColor(vec3 N)
{
    //return  textureLod(uCubeMap, N, 3.0).rgb;
    vec3 color = vec3_splat(0.f);
    float weight = 0.0f;

    for(int i = 0; i < u_sampleCount; ++i)
    {
        vec4 importanceSample = getImportanceSample(i, N, u_roughness);

        vec3 H = vec3(importanceSample.xyz);
        float pdf = importanceSample.w;

        // mipmap filtered samples (GPU Gems 3, 20.4)
        float lod = computeLod(pdf);

        // apply the bias to the lod
        lod += u_lodBias;

        if(u_distribution == cLambertian)
        {
            // sample lambertian at a lower resolution to avoid fireflies
            //vec3 lambertian = textureLod(uCubeMap, H, lod).rgb;
            vec3 lambertian = sample_source(H, lod);

            //// the below operations cancel each other out
            // lambertian *= NdotH; // lamberts law
            // lambertian /= pdf; // invert bias from importance sampling
            // lambertian /= M_PI; // convert irradiance to radiance https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/

            color += lambertian;
        }
        else if(u_distribution == cGGX || u_distribution == cCharlie)
        {
            // Note: reflect takes incident vector.
            vec3 V = N;
            vec3 L = normalize(reflect(-V, H));
            float NdotL = dot(N, L);

            if (NdotL > 0.0)
            {
                if(u_roughness == 0.0)
                {
                    // without this the roughness=0 lod is too high
                    lod = u_lodBias;
                }
                //vec3 sampleColor = textureLod(uCubeMap, L, lod).rgb;
                vec3 sampleColor = sample_source(L, lod);
                color += sampleColor * NdotL;
                weight += NdotL;
            }
        }
    }

    if(weight != 0.0f)
    {
        color /= weight;
    }
    else
    {
        color /= float(u_sampleCount);
    }

    return color.rgb ;
}

// From the filament docs. Geometric Shadowing function
// https://google.github.io/filament/Filament.html#toc4.4.2
float V_SmithGGXCorrelated(float NoV, float NoL, float roughness) {
    float a2 = pow(roughness, 4.0);
    float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
    float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
    return 0.5 / (GGXV + GGXL);
}

// Compute LUT for GGX distribution.
// See https://blog.selfshadow.com/publications/s2013-shading-course/karis/s2013_pbs_epic_notes_v2.pdf
vec3 LUT(float NdotV, float roughness)
{
    // Compute spherical view vector: (sin(phi), 0, cos(phi))
    vec3 V = vec3(sqrt(1.0 - NdotV * NdotV), 0.0, NdotV);

    // The macro surface normal just points up.
    vec3 N = vec3(0.0, 0.0, 1.0);

    // To make the LUT independant from the material's F0, which is part of the Fresnel term
    // when substituted by Schlick's approximation, we factor it out of the integral,
    // yielding to the form: F0 * I1 + I2
    // I1 and I2 are slighlty different in the Fresnel term, but both only depend on
    // NoL and roughness, so they are both numerically integrated and written into two channels.
    float A = 0.0;
    float B = 0.0;
    float C = 0.0;

    for(int i = 0; i < u_sampleCount; ++i)
    {
        // Importance sampling, depending on the distribution.
        vec4 importanceSample = getImportanceSample(i, N, roughness);
        vec3 H = importanceSample.xyz;
        // float pdf = importanceSample.w;
        vec3 L = normalize(reflect(-V, H));

        float NdotL = saturate(L.z);
        float NdotH = saturate(H.z);
        float VdotH = saturate(dot(V, H));
        if (NdotL > 0.0)
        {
            if (u_distribution == cGGX)
            {
                // LUT for GGX distribution.

                // Taken from: https://bruop.github.io/ibl
                // Shadertoy: https://www.shadertoy.com/view/3lXXDB
                // Terms besides V are from the GGX PDF we're dividing by.
                float V_pdf = V_SmithGGXCorrelated(NdotV, NdotL, roughness) * VdotH * NdotL / NdotH;
                float Fc = pow(1.0 - VdotH, 5.0);
                A += (1.0 - Fc) * V_pdf;
                B += Fc * V_pdf;
                C += 0.0;
            }

        }
    }

    // The PDF is simply pdf(v, h) -> NDF * <nh>.
    // To parametrize the PDF over l, use the Jacobian transform, yielding to: pdf(v, l) -> NDF * <nh> / 4<vh>
    // Since the BRDF divide through the PDF to be normalized, the 4 can be pulled out of the integral.
    return vec3(4.0 * A, 4.0 * B, 4.0 * 2.0 * M_PI * C) / float(u_sampleCount);
}



// entry point
void main()
{
    vec3 color = vec3_splat(0.0);

    if(u_isGeneratingLUT == 0)
    {
        vec2 newUV = v_texcoord0*2.0-1.0;
        vec3 direction = normalize(get_sample_vec(u_currentFace, newUV));
        direction.y = -direction.y;
        color = filterColor(direction);
    }
    else
    {
        color = LUT(v_texcoord0.x, v_texcoord0.y);
    }
    
    gl_FragColor = vec4(color,1.0);
}

