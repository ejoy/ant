//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "..\\PCH.h"
#include "..\\SF11_Math.h"

namespace SampleFramework11
{

// Calculates the Fresnel factor using Schlick's approximation
inline Float3 Fresnel(Float3 specAlbedo, Float3 h, Float3 l)
{
    Float3 fresnel = specAlbedo + (Float3(1.0f) - specAlbedo) * std::pow((1.0f - Saturate(Float3::Dot(l, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    fresnel *= Saturate(Float3::Dot(specAlbedo, 333.0f));

    return fresnel;
}

// Calculates the Fresnel factor using Schlick's approximation
inline Float3 Fresnel(Float3 specAlbedo, Float3 fresnelAlbedo, Float3 h, Float3 l)
{
    Float3 fresnel = specAlbedo + (fresnelAlbedo - specAlbedo) * std::pow((1.0f - Saturate(Float3::Dot(l, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    fresnel *= Saturate(Float3::Dot(specAlbedo, 333.0f));

    return fresnel;
}

// Helper for computing the GGX visibility term
inline float GGX_V1(float m2, float nDotX)
{
    return 1.0f / (nDotX + sqrt(m2 + (1 - m2) * nDotX * nDotX));
}

// Computes the specular term using a GGX microfacet distribution, with a matching
// geometry factor and visibility term. Based on "Microfacet Models for Refraction Through
// Rough Surfaces" [Walter 07]. m is roughness, n is the surface normal, h is the half vector,
// l is the direction to the light source, and specAlbedo is the RGB specular albedo
inline float GGX_Specular(float m, const Float3& n, const Float3& h, const Float3& v, const Float3& l)
{
    float nDotH = Saturate(Float3::Dot(n, h));
    float nDotL = Saturate(Float3::Dot(n, l));
    float nDotV = Saturate(Float3::Dot(n, v));

    float nDotH2 = nDotH * nDotH;
    float m2 = m * m;

    // Calculate the distribution term
    float d = m2 / (Pi * Square(nDotH * nDotH * (m2 - 1) + 1));

    // Calculate the matching visibility term
    float v1i = GGX_V1(m2, nDotL);
    float v1o = GGX_V1(m2, nDotV);
    float vis = v1i * v1o;

    return d * vis;
}
// Computes the radiance reflected off a surface towards the eye given
// the differential irradiance from a given direction
inline Float3 CalcLighting(const Float3& normal, const Float3& lightIrradiance,
                    const Float3& lightDir, const Float3& diffuseAlbedo, const Float3& position,
                    const Float3& cameraPos, float roughness, bool includeSpecular, Float3 specAlbedo)
{
    Float3 lighting = diffuseAlbedo * InvPi;

    if(includeSpecular && Float3::Dot(normal, lightDir) > 0.0f)
    {
        Float3 view = Float3::Normalize(cameraPos - position);
        Float3 h = Float3::Normalize(view + lightDir);

        Float3 fresnel = Fresnel(specAlbedo, h, lightDir);

        float specular = GGX_Specular(roughness, normal, h, view, lightDir);
        lighting += specular * fresnel;
    }

    return lighting * lightIrradiance;
}

}