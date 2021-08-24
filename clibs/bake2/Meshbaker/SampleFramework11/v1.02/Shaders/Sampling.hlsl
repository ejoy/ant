//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#ifndef SAMPLING_HLSL_
#define SAMPLING_HLSL_

#include <Quaternion.hlsl>

// Maps a value inside the square [0,1]x[0,1] to a value in a disk of radius 1 using concentric squares.
// This mapping preserves area, bi continuity, and minimizes deformation.
// Based off the algorithm "A Low Distortion Map Between Disk and Square" by Peter Shirley and
// Kenneth Chiu. Also includes polygon morphing modification from "CryEngine3 Graphics Gems"
// by Tiago Sousa
float2 SquareToConcentricDiskMapping(float x, float y, float numSides, float polygonAmount)
{
    float phi, r;

    // -- (a,b) is now on [-1,1]ˆ2
    float a = 2.0f * x - 1.0f;
    float b = 2.0f * y - 1.0f;

    if(a > -b)                      // region 1 or 2
    {
        if(a > b)                   // region 1, also |a| > |b|
        {
            r = a;
            phi = (Pi / 4.0f) * (b / a);
        }
        else                        // region 2, also |b| > |a|
        {
            r = b;
            phi = (Pi / 4.0f) * (2.0f - (a / b));
        }
    }
    else                            // region 3 or 4
    {
        if(a < b)                   // region 3, also |a| >= |b|, a != 0
        {
            r = -a;
            phi = (Pi / 4.0f) * (4.0f + (b / a));
        }
        else                        // region 4, |b| >= |a|, but a==0 and b==0 could occur.
        {
            r = -b;
            if(b != 0)
                phi = (Pi / 4.0f) * (6.0f - (a / b));
            else
                phi = 0;
        }
    }

    const float N = numSides;
    float polyModifier = cos(Pi / N) / cos(phi - (Pi2 / N) * floor((N * phi + Pi) / Pi2));
    r *= lerp(1.0f, polyModifier, polygonAmount);

    float2 result;
    result.x = r * cos(phi);
    result.y = r * sin(phi);

    return result;
}

// Maps a value inside the square [0,1]x[0,1] to a value in a disk of radius 1 using concentric squares.
// This mapping preserves area, bi continuity, and minimizes deformation.
// Based off the algorithm "A Low Distortion Map Between Disk and Square" by Peter Shirley and
// Kenneth Chiu.
float2 SquareToConcentricDiskMapping(float x, float y)
{
    float phi = 0.0f;
    float r = 0.0f;

    // -- (a,b) is now on [-1,1]ˆ2
    float a = 2.0f * x - 1.0f;
    float b = 2.0f * y - 1.0f;

    if(a > -b)                      // region 1 or 2
    {
        if(a > b)                   // region 1, also |a| > |b|
        {
            r = a;
            phi = (Pi / 4.0f) * (b / a);
        }
        else                        // region 2, also |b| > |a|
        {
            r = b;
            phi = (Pi / 4.0f) * (2.0f - (a / b));
        }
    }
    else                            // region 3 or 4
    {
        if(a < b)                   // region 3, also |a| >= |b|, a != 0
        {
            r = -a;
            phi = (Pi / 4.0f) * (4.0f + (b / a));
        }
        else                        // region 4, |b| >= |a|, but a==0 and b==0 could occur.
        {
            r = -b;
            if(b != 0)
                phi = (Pi / 4.0f) * (6.0f - (a / b));
            else
                phi = 0;
        }
    }

    float2 result;
    result.x = r * cos(phi);
    result.y = r * sin(phi);
    return result;
}

// Returns a random microfacet normal sampled from a GGX distribution (in tangent space)
float3 SampleGGXMicrofacet(float roughness, float u1, float u2)
{
    float theta = atan2(roughness * sqrt(u1), sqrt(1 - u1));
    float phi = 2 * Pi * u2;

    float3 h;
    h.x = sin(theta) * cos(phi);
    h.y = sin(theta) * sin(phi);
    h.z = cos(theta);

    return h;
}

// Returns a random reflected direction for sampling a GGX distribution (in tangent space)
float3 SampleDirectionGGX(float3 v, float3 n, float roughness, float u1, float u2)
{
    float3 h = SampleGGXMicrofacet(roughness, u1, u2);
    return normalize(2.0f * dot(h, v) * h - v);
}

float3 SampleGGXVisibleNormal(float3 wo, float ax, float ay, float u1, float u2)
{
    // Stretch the view vector so we are sampling as though
    // roughness==1
    float3 v = normalize(float3(wo.x * ax, wo.y * ay, wo.z));

    // Build an orthonormal basis with v, t1, and t2
    float3 t1 = (v.z < 0.999f) ? normalize(cross(v, float3(0, 0, 1))) : float3(1, 0, 0);
    float3 t2 = cross(t1, v);

    // Choose a point on a disk with each half of the disk weighted
    // proportionally to its projection onto direction v
    float a = 1.0f / (1.0f + v.z);
    float r = sqrt(u1);
    float phi = (u2 < a) ? (u2 / a) * Pi : Pi + (u2 - a) / (1.0f - a) * Pi;
    float p1 = r * cos(phi);
    float p2 = r * sin(phi) * ((u2 < a) ? 1.0f : v.z);

    // Calculate the normal in this stretched tangent space
    float3 n = p1 * t1 + p2 * t2 + sqrt(max(0.0f, 1.0f - p1 * p1 - p2 * p2)) * v;

    // Unstretch and normalize the normal
    return normalize(float3(ax * n.x, ay * n.y, max(0.0f, n.z)));
}

// Returns a random direction on the unit sphere
float3 SampleDirectionSphere(float u1, float u2)
{
    float z = u1 * 2.0f - 1.0f;
    float r = sqrt(max(0.0f, 1.0f - z * z));
    float phi = 2 * Pi * u2;
    float x = r * cos(phi);
    float y = r * sin(phi);

    return float3(x, y, z);
}

// Returns a random direction on the hemisphere around z = 1
float3 SampleDirectionHemisphere(float u1, float u2)
{
    float z = u1;
    float r = sqrt(max(0.0f, 1.0f - z * z));
    float phi = 2 * Pi * u2;
    float x = r * cos(phi);
    float y = r * sin(phi);

    return float3(x, y, z);
}

// Returns a random cosine-weighted direction on the hemisphere around z = 1
float3 SampleDirectionCosineHemisphere(float u1, float u2)
{
    float2 uv = SquareToConcentricDiskMapping(u1, u2);
    float u = uv.x;
    float v = uv.y;

    // Project samples on the disk to the hemisphere to get a
    // cosine weighted distribution
    float3 dir;
    float r = u * u + v * v;
    dir.x = u;
    dir.y = v;
    dir.z = sqrt(max(0.0f, 1.0f - r));

    return dir;
}

// Returns a random direction from within a cone with angle == theta
float3 SampleDirectionCone(float u1, float u2, float cosThetaMax)
{
    float cosTheta = (1.0f - u1) + u1 * cosThetaMax;
    float sinTheta = sqrt(1.0f - cosTheta * cosTheta);
    float phi = u2 * 2.0f * Pi;
    return float3(cos(phi) * sinTheta, sin(phi) * sinTheta, cosTheta);
}

// Returns a direction that samples a rectangular area light
float3 SampleDirectionRectangularLight(float u1, float u2, float3 sourcePos, float2 lightSize, float3 lightPos,
                                       Quaternion lightOrientation, float distanceToLight)
{
    float x = u1 - 0.5f;
    float y = u2 - 0.5f;

    float3x3 lightBasis = QuatTo3x3(lightOrientation);
    float3 lightBasisX = lightBasis._11_12_13;
    float3 lightBasisY = lightBasis._21_22_23;
    float3 lightBasisZ = lightBasis._31_32_33;

    // Pick random sample point
    float3 samplePos = lightPos +
                       lightBasisX * x * lightSize.x +
                       lightBasisY * y * lightSize.y;

    float3 sampleDir = samplePos - sourcePos;
    distanceToLight = length(sampleDir);
    if(distanceToLight > 0.0f)
        sampleDir /= distanceToLight;

    return sampleDir;
}

// Returns the PDF for a particular GGX sample
float SampleDirectionGGX_PDF(float3 n, float3 h, float3 v, float roughness)
{
    float nDotH = saturate(dot(n, h));
    float hDotV = saturate(dot(h, v));
    float m2 = roughness * roughness;
    float x = nDotH * nDotH * (m2 - 1) + 1;
    float d = m2 / (Pi * x * x);
    float pM = d * nDotH;
    return pM / (4 * hDotV);
}

// Returns the (constant) PDF of sampling uniform directions on the unit sphere
float SampleDirectionSphere_PDF()
{
    return 1.0f / (Pi * 4.0f);
}

// Returns the (constant) PDF of sampling uniform directions on a unit hemisphere
float SampleDirectionHemisphere_PDF()
{
    return 1.0f / (Pi * 2.0f);
}

// Returns the PDF of of a single sample on a cosine-weighted hemisphere
float SampleDirectionCosineHemisphere_PDF(float cosTheta)
{
    return cosTheta / Pi;
}

// Returns the PDF of of a single sample on a cosine-weighted hemisphere
float SampleDirectionCosineHemisphere_PDF(float3 normal, float3 sampleDir)
{
    return saturate(dot(normal, sampleDir)) / Pi;
}

// Returns the PDF of of a single uniform sample within a cone
float SampleDirectionCone_PDF(float cosThetaMax)
{
    return 1.0f / (2.0f * Pi * (1.0f - cosThetaMax));
}

// Returns the PDF of of a single sample on a rectangular area light
float SampleDirectionRectangularLight_PDF(float2 lightSize, float3 sampleDir, Quaternion lightOrientation, float distanceToLight)
{
    float3 lightBasisZ = QuatRotate(float3(0.0f, 0.0f, -1.0f), lightOrientation);
    float areaNDotL = saturate(dot(sampleDir, lightBasisZ));
    return (distanceToLight * distanceToLight) / (areaNDotL * lightSize.x * lightSize.y);
}

#pragma warning(push)
#pragma warning(disable : 3557)     // loop only executes for one iteration

uint CMJPermute(uint i, uint l, uint p)
{
    uint w = l - 1;
    w |= w >> 1;
    w |= w >> 2;
    w |= w >> 4;
    w |= w >> 8;
    w |= w >> 16;
    do
    {
        i ^= p; i *= 0xe170893d;
        i ^= p >> 16;
        i ^= (i & w) >> 4;
        i ^= p >> 8; i *= 0x0929eb3f;
        i ^= p >> 23;
        i ^= (i & w) >> 1; i *= 1 | p >> 27;
        i *= 0x6935fa69;
        i ^= (i & w) >> 11; i *= 0x74dcb303;
        i ^= (i & w) >> 2; i *= 0x9e501cc3;
        i ^= (i & w) >> 2; i *= 0xc860a3df;
        i &= w;
        i ^= i >> 5;
    }
    while (i >= l);
    return (i + p) % l;
}

#pragma warning(pop)

float CMJRandFloat(uint i, uint p)
{
    i ^= p;
    i ^= i >> 17;
    i ^= i >> 10; i *= 0xb36534e5;
    i ^= i >> 12;
    i ^= i >> 21; i *= 0x93fc4795;
    i ^= 0xdf6e307f;
    i ^= i >> 17; i *= 1 | p >> 18;
    return i * (1.0f / 4294967808.0f);
}

 // Returns a 2D sample from a particular pattern using correlated multi-jittered sampling [Kensler 2013]
float2 SampleCMJ2D(uint sampleIdx, uint numSamplesX, uint numSamplesY, uint pattern)
{
    uint N = numSamplesX * numSamplesY;
    sampleIdx = CMJPermute(sampleIdx, N, pattern * 0x51633e2d);
    uint sx = CMJPermute(sampleIdx % numSamplesX, numSamplesX, pattern * 0x68bc21eb);
    uint sy = CMJPermute(sampleIdx / numSamplesX, numSamplesY, pattern * 0x02e5be93);
    float jx = CMJRandFloat(sampleIdx, pattern * 0x967a889b);
    float jy = CMJRandFloat(sampleIdx, pattern * 0x368cc8b7);
    return float2((sx + (sy + jx) / numSamplesY) / numSamplesX, (sampleIdx + jy) / N);
}


#endif // SAMPLING_HLSL_