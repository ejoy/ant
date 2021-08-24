//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//-------------------------------------------------------------------------------------------------
// Calculates the Fresnel factor using Schlick's approximation
//-------------------------------------------------------------------------------------------------
float3 Fresnel(in float3 specAlbedo, in float3 h, in float3 l)
{
    float3 fresnel = specAlbedo + (1.0f - specAlbedo) * pow((1.0f - saturate(dot(l, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    fresnel *= saturate(dot(specAlbedo, 333.0f));

    return fresnel;
}

//-------------------------------------------------------------------------------------------------
// Calculates the Fresnel factor using Schlick's approximation
//-------------------------------------------------------------------------------------------------
float3 Fresnel(in float3 specAlbedo, in float3 fresnelAlbedo, in float3 h, in float3 l)
{
    float3 fresnel = specAlbedo + (fresnelAlbedo - specAlbedo) * pow((1.0f - saturate(dot(l, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    fresnel *= saturate(dot(specAlbedo, 333.0f));

    return fresnel;
}

//-------------------------------------------------------------------------------------------------
// Helper for computing the Beckmann geometry term
//-------------------------------------------------------------------------------------------------
float Beckmann_G1(float m, float nDotX)
{
    float nDotX2 = nDotX * nDotX;
    float tanTheta = sqrt((1 - nDotX2) / nDotX2);
    float a = 1.0f / (m * tanTheta);
    float a2 = a * a;

    float g = 1.0f;
    if(a < 1.6f)
        g *= (3.535f * a + 2.181f * a2) / (1.0f + 2.276f * a + 2.577f * a2);

    return g;
}

//-------------------------------------------------------------------------------------------------
// Computes the specular term using a Beckmann microfacet distribution, with a matching
// geometry factor and visibility term. Based on "Microfacet Models for Refraction Through
// Rough Surfaces" [Walter 07]. m is roughness, n is the surface normal, h is the half vector,
// l is the direction to the light source, and specAlbedo is the RGB specular albedo
//-------------------------------------------------------------------------------------------------
float Beckmann_Specular(in float m, in float3 n, in float3 h, in float3 v, in float3 l)
{
    float nDotH = max(dot(n, h), 0.0001f);
    float nDotL = saturate(dot(n, l));
    float nDotV = max(dot(n, v), 0.0001f);

    float nDotH2 = nDotH * nDotH;
    float nDotH4 = nDotH2 * nDotH2;
    float m2 = m * m;

    // Calculate the distribution term
    float tanTheta2 = (1 - nDotH2) / nDotH2;
    float expTerm = exp(-tanTheta2 / m2);
    float d = expTerm / (Pi * m2 * nDotH4);

    // Calculate the matching geometric term
    float g1i = Beckmann_G1(m, nDotL);
    float g1o = Beckmann_G1(m, nDotV);
    float g = g1i * g1o;

    return d * g * (1.0f / (4.0f * nDotL * nDotV));
}


//-------------------------------------------------------------------------------------------------
// Helper for computing the GGX visibility term
//-------------------------------------------------------------------------------------------------
float GGX_V1(in float m2, in float nDotX)
{
    return 1.0f / (nDotX + sqrt(m2 + (1 - m2) * nDotX * nDotX));
}

//-------------------------------------------------------------------------------------------------
// Computes the GGX visibility term
//-------------------------------------------------------------------------------------------------
float GGXVisibility(in float m2, in float nDotL, in float nDotV)
{
    return GGX_V1(m2, nDotL) * GGX_V1(m2, nDotV);
}

//-------------------------------------------------------------------------------------------------
// Computes the specular term using a GGX microfacet distribution, with a matching
// geometry factor and visibility term. Based on "Microfacet Models for Refraction Through
// Rough Surfaces" [Walter 07]. m is roughness, n is the surface normal, h is the half vector,
// l is the direction to the light source, and specAlbedo is the RGB specular albedo
//-------------------------------------------------------------------------------------------------
float GGX_Specular(in float m, in float3 n, in float3 h, in float3 v, in float3 l)
{
    float nDotH = saturate(dot(n, h));
    float nDotL = saturate(dot(n, l));
    float nDotV = saturate(dot(n, v));

    float nDotH2 = nDotH * nDotH;
    float m2 = m * m;

    // Calculate the distribution term
    float x = nDotH * nDotH * (m2 - 1) + 1;
    float d = m2 / (Pi * x * x);

    return d * GGXVisibility(m2, nDotL, nDotV);
}

// Distribution term for the velvet BRDF
float VelvetDistribution(in float m, in float nDotH2, in float offset)
{
    float cot2 = nDotH2 / (1.000001f - nDotH2);
    float sin2 = 1.0f - nDotH2;
    float sin4 = sin2 * sin2;
    float amp = 4.0f;
    float m2 = m * m + 0.000001f;
    float cnorm = 1.0f / (Pi * (offset + amp * m2));

    return cnorm * (offset + (amp * exp(-cot2 / (m2 + 0.000001f)) / sin4));
}

// Specular term for the velvet BRDF
float Velvet_Specular(in float m, in float3 n, in float3 h, in float3 v, in float3 l, in float offset)
{
    float nDotH = saturate(dot(n, h));
    float nDotH2 = nDotH * nDotH;
    float nDotV = saturate(dot(n, v));
    float nDotL = saturate(dot(n, l));

    float D = VelvetDistribution(m, nDotH2, offset);
    float G = 1.0f;
    float denom = 1.0f / (4.0f * (nDotL + nDotV - nDotL * nDotV));
    return D * G * denom;
}