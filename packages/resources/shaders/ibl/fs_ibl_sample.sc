//#version 450
//#extension GL_ARB_separate_shader_objects : enable

precision mediump float;
#define MATH_PI 3.1415926535897932384626433832795
//#define MATH_INV_PI (1.0 / MATH_PI)

uniform samplerCube uCubeMap;

// enum
const int cLambertian = 0;
const int cGGX = 1;
const int cCharlie = 2;

//layout(push_constant) uniform FilterParameters {
uniform  float u_roughness;
uniform  int u_sample_count;
uniform  int u_width;
uniform  float u_lod_bias;
uniform  int u_distribution; // enum
uniform int u_currentFace;


//layout (location = 0) in vec2 inUV;
in vec2 texCoord;


out vec4 fragmentColor;

//layout(location = 6) out vec3 outLUT;


// Hemisphere Sample

// TBN generates a tangent bitangent normal coordinate frame from the normal
// (the normal must be normalized)
mat3 generateTBN(vec3 normal)
{
    vec3 bitangent = vec3(0.0, 1.0, 0.0);

    float NdotUp = dot(normal, vec3(0.0, 1.0, 0.0));
    float epsilon = 0.0000001;
    if (1.0 - abs(NdotUp) <= epsilon)
    {
        // Sampling +Y or -Y, so we need a more robust bitangent.
        if (NdotUp > 0.0)
        {
            bitangent = vec3(0.0, 0.0, 1.0);
        }
        else
        {
            bitangent = vec3(0.0, 0.0, -1.0);
        }
    }

    vec3 tangent = normalize(cross(bitangent, normal));
    bitangent = cross(normal, tangent);

    return mat3(tangent, bitangent, normal);
}

// NDF
float D_GGX(float NdotH, float roughness)
{
    float alpha = roughness * roughness;

    float alpha2 = alpha * alpha;

    float divisor = NdotH * NdotH * (alpha2 - 1.0) + 1.0;

    return alpha2 / (MATH_PI * divisor * divisor);
}

// NDF
float D_Ashikhmin(float NdotH, float roughness)
{
    float alpha = roughness * roughness;
    // Ashikhmin 2007, "Distribution-based BRDFs"
    float a2 = alpha * alpha;
    float cos2h = NdotH * NdotH;
    float sin2h = 1.0 - cos2h;
    float sin4h = sin2h * sin2h;
    float cot2 = -cos2h / (a2 * sin2h);
    return 1.0 / (MATH_PI * (4.0 * a2 + 1.0) * sin4h) * (4.0 * exp(cot2) + sin4h);
}

// NDF
float D_Charlie(float sheenRoughness, float NdotH)
{
    sheenRoughness = max(sheenRoughness, 0.000001); //clamp (0,1]
    float alphaG = sheenRoughness * sheenRoughness;
    float invR = 1.0 / alphaG;
    float cos2h = NdotH * NdotH;
    float sin2h = 1.0 - cos2h;
    return (2.0 + invR) * pow(sin2h, invR * 0.5) / (2.0 * MATH_PI);
}

float PDF(vec3 H, vec3 N, float roughness)
{
    float NdotH = dot(N, H);
    if(u_distribution == cLambertian)
    {
        return max(NdotH * (1.0 / MATH_PI), 0.0);
    }
    else if(u_distribution == cGGX)
    {
        float D = D_GGX(NdotH, roughness);
        return max(D / 4.0, 0.0);
    }
    else if(u_distribution == cCharlie)
    {
        float D = D_Charlie(roughness, NdotH);
        return max(D / 4.0, 0.0);
    }

    return 0.f;
}

// https://github.com/google/filament/blob/master/shaders/src/brdf.fs#L136
float V_Ashikhmin(float NdotL, float NdotV)
{
    return clamp(1.0 / (4.0 * (NdotL + NdotV - NdotL * NdotV)), 0.0, 1.0);
}

// Mipmap Filtered Samples (GPU Gems 3, 20.4)
// https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-20-gpu-based-importance-sampling
float computeLod(float pdf)
{
    // IBL Baker (Matt Davidson)
    // https://github.com/derkreature/IBLBaker/blob/65d244546d2e79dd8df18a28efdabcf1f2eb7717/data/shadersD3D11/IblImportanceSamplingDiffuse.fx#L215
    float solidAngleTexel = 4.0 * MATH_PI / (6.0 * float(u_width) * float(u_sample_count));
    float solidAngleSample = 1.0 / (float(u_sample_count) * pdf);
    float lod = 0.5 * log2(solidAngleSample / solidAngleTexel);

    return lod;
}

vec3 filterColor(vec3 N)
{
    //return  textureLod(uCubeMap, N, 3.0).rgb;
    vec4 color = vec4(0.f);

    for(int i = 0; i < u_sample_count; ++i)
    {
        vec4 importanceSample = getImportanceSample(i, N, u_roughness);

        vec3 H = vec3(importanceSample.xyz);
        float pdf = importanceSample.w;

        // mipmap filtered samples (GPU Gems 3, 20.4)
        float lod = computeLod(pdf);

        // apply the bias to the lod
        lod += u_lod_bias;

        if(u_distribution == cLambertian)
        {
            float NdotH = clamp(dot(N, H), 0.0, 1.0);

            // sample lambertian at a lower resolution to avoid fireflies
            vec3 lambertian = textureLod(uCubeMap, H, lod).rgb;

            //// the below operations cancel each other out
            // lambertian *= NdotH; // lamberts law
            // lambertian /= pdf; // invert bias from importance sampling
            // lambertian /= MATH_PI; // convert irradiance to radiance https://seblagarde.wordpress.com/2012/01/08/pi-or-not-to-pi-in-game-lighting-equation/

            color += vec4(lambertian, 1.0);
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
                    // without this the roughness=0 lod is too high (taken from original implementation)
                    lod = u_lod_bias;
                }

                color += vec4(textureLod(uCubeMap, L, lod).rgb * NdotL, NdotL);
            }
        }
    }

    if(color.w == 0.f)
    {
        return color.rgb;
    }

    return color.rgb / color.w;
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

    for(int i = 0; i < u_sample_count; ++i)
    {
        // Importance sampling, depending on the distribution.
        vec3 H = getImportanceSample(i, N, roughness).xyz;
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

            if (u_distribution == cCharlie)
            {
                // LUT for Charlie distribution.

                float sheenDistribution = D_Charlie(roughness, NdotH);
                float sheenVisibility = V_Ashikhmin(NdotL, NdotV);

                A += 0.0;
                B += 0.0;
                C += sheenVisibility * sheenDistribution * NdotL * VdotH;
            }
        }
    }

    // The PDF is simply pdf(v, h) -> NDF * <nh>.
    // To parametrize the PDF over l, use the Jacobian transform, yielding to: pdf(v, l) -> NDF * <nh> / 4<vh>
    // Since the BRDF divide through the PDF to be normalized, the 4 can be pulled out of the integral.
    return vec3(4.0 * A, 4.0 * B, 4.0 * 2.0 * MATH_PI * C) / float(u_sample_count);
}



// entry point
void main()
{
    vec2 newUV = texCoord ;

    newUV = newUV*2.0-1.0;

    vec3 scan = uvToXYZ(u_currentFace, newUV);

    vec3 direction = normalize(scan);
    direction.y = -direction.y;

    vec3 color = filterColor(direction);

    fragmentColor = vec4(color,1.0);

}

