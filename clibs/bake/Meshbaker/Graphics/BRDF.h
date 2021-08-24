//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "glm/glm.hpp"
namespace Graphics
{

// Calculates the Fresnel factor using Schlick's approximation
inline glm::vec3 Fresnel(glm::vec3 specAlbedo, glm::vec3 h, glm::vec3 l)
{
    glm::vec3 fresnel = specAlbedo + (glm::vec3(1.0f) - specAlbedo) * std::pow((1.0f - Saturate(glm::vec3::Dot(l, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    fresnel *= Saturate(glm::vec3::Dot(specAlbedo, 333.0f));

    return fresnel;
}

// Calculates the Fresnel factor using Schlick's approximation
inline glm::vec3 Fresnel(glm::vec3 specAlbedo, glm::vec3 fresnelAlbedo, glm::vec3 h, glm::vec3 l)
{
    glm::vec3 fresnel = specAlbedo + (fresnelAlbedo - specAlbedo) * std::pow((1.0f - Saturate(glm::vec3::Dot(l, h))), 5.0f);

    // Fade out spec entirely when lower than 0.1% albedo
    fresnel *= Saturate(glm::vec3::Dot(specAlbedo, 333.0f));

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
inline float GGX_Specular(float m, const glm::vec3& n, const glm::vec3& h, const glm::vec3& v, const glm::vec3& l)
{
    float nDotH = Saturate(glm::vec3::Dot(n, h));
    float nDotL = Saturate(glm::vec3::Dot(n, l));
    float nDotV = Saturate(glm::vec3::Dot(n, v));

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
inline glm::vec3 CalcLighting(const glm::vec3& normal, const glm::vec3& lightIrradiance,
                    const glm::vec3& lightDir, const glm::vec3& diffuseAlbedo, const glm::vec3& position,
                    const glm::vec3& cameraPos, float roughness, bool includeSpecular, glm::vec3 specAlbedo)
{
    glm::vec3 lighting = diffuseAlbedo * InvPi;

    if(includeSpecular && glm::dot(normal, lightDir) > 0.0f)
    {
        glm::vec3 view = glm::normalize(cameraPos - position);
        glm::vec3 h = glm::normalize(view + lightDir);

        glm::vec3 fresnel = Fresnel(specAlbedo, h, lightDir);

        float specular = GGX_Specular(roughness, normal, h, view, lightDir);
        lighting += specular * fresnel;
    }

    return lighting * lightIrradiance;
}

}