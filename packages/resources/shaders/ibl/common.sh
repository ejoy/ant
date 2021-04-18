// from: https://github.com/KhronosGroup/glTF-Sample-Viewer/blob/master/source/shaders/ibl_filtering.frag

uniform vec4 u_ibl_param;
#define u_sample_count u_ibl_param.x;
#define u_lodBias u_ibl_param.y;

vec3 uvToXYZ(int face, vec2 uv)
{
    if(face == 0)
        return vec3(     1.f,   uv.y,    -uv.x);

    if(face == 1)
        return vec3(    -1.f,   uv.y,     uv.x);

    if(face == 2)
        return vec3(   +uv.x,   -1.f,    +uv.y);

    if(face == 3)
        return vec3(   +uv.x,    1.f,    -uv.y);

    if(face == 4)
        return vec3(   +uv.x,   uv.y,      1.f);

    //if(face == 5)
    return vec3(    -uv.x,  +uv.y,     -1.f);
}

vec2 dirToUV(vec3 dir)
{
    return vec2(
            0.5f + 0.5f * atan(dir.z, dir.x) / MATH_PI,
            1.f - acos(dir.y) / MATH_PI);
}

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

// Mipmap Filtered Samples (GPU Gems 3, 20.4)
// https://developer.nvidia.com/gpugems/gpugems3/part-iii-rendering/chapter-20-gpu-based-importance-sampling
float computeLod(float pdf)
{
    // IBL Baker (Matt Davidson)
    // https://github.com/derkreature/IBLBaker/blob/65d244546d2e79dd8df18a28efdabcf1f2eb7717/data/shadersD3D11/IblImportanceSamplingDiffuse.fx#L215
    float solidAngleTexel = 4.0 * MATH_PI / (6.0 * float(u_width) * float(u_sampleCount));
    float solidAngleSample = 1.0 / (float(u_sampleCount) * pdf);
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

// getImportanceSample returns an importance sample direction with pdf in the .w component
vec4 getImportanceSample(int sampleIndex, vec3 N, float roughness)
{
    // generate a quasi monte carlo point in the unit square [0.1)^2
    vec2 hammersleyPoint = hammersley2d(sampleIndex, u_sampleCount);
    float u = hammersleyPoint.x;
    float v = hammersleyPoint.y;

    // declare importance sample parameters
    float phi = 0.0; // theoretically there could be a distribution that defines phi differently
    float cosTheta = 0.f;
    float sinTheta = 0.f;
    float pdf = 0.0;

    // generate the points on the hemisphere with a fitting mapping for
    // the distribution (e.g. lambertian uses a cosine importance)
    if(u_distribution == cLambertian)
    {
        // Cosine weighted hemisphere sampling
        // http://www.pbr-book.org/3ed-2018/Monte_Carlo_Integration/2D_Sampling_with_Multidimensional_Transformations.html#Cosine-WeightedHemisphereSampling
        cosTheta = sqrt(1.0 - u);
        sinTheta = sqrt(u); // equivalent to `sqrt(1.0 - cosTheta*cosTheta)`;
        phi = 2.0 * MATH_PI * v;

        pdf = cosTheta / MATH_PI; // evaluation for solid angle, therefore drop the sinTheta
    }
    else if(u_distribution == cGGX)
    {
        // specular mapping
        float alpha = roughness * roughness;
        cosTheta = sqrt((1.0 - u) / (1.0 + (alpha*alpha - 1.0) * u));
        sinTheta = sqrt(1.0 - cosTheta*cosTheta);
        phi = 2.0 * MATH_PI * v;
    }
    else if(u_distribution == cCharlie)
    {
        // sheen mapping
        float alpha = roughness * roughness;
        sinTheta = pow(u, alpha / (2.0*alpha + 1.0));
        cosTheta = sqrt(1.0 - sinTheta * sinTheta);
        phi = 2.0 * MATH_PI * v;
    }

    // transform the hemisphere sample to the normal coordinate frame
    // i.e. rotate the hemisphere to the normal direction
    vec3 localSpaceDirection = normalize(vec3(sinTheta * cos(phi), sinTheta * sin(phi), cosTheta));
    mat3 TBN = generateTBN(N);
    vec3 direction = TBN * localSpaceDirection;

    if(u_distribution == cGGX || u_distribution == cCharlie)
    {
        pdf = PDF(direction, N, roughness);
    }

    return vec4(direction, pdf);
}