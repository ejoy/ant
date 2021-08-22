//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "PathTracer.h"

#include <Graphics/BRDF.h>
#include <Graphics/Sampling.h>

// Vertex operators
inline Vertex operator+(const Vertex& a, const Vertex& b)
{
    Vertex c;
    c.Position = a.Position + b.Position;
    c.Normal = a.Normal + b.Normal;
    c.TexCoord = a.TexCoord + b.TexCoord;
    c.LightMapUV = a.LightMapUV + b.LightMapUV;
    c.Tangent = a.Tangent + b.Tangent;
    c.Bitangent = a.Bitangent + b.Bitangent;
    return c;
}

inline Vertex operator-(const Vertex& a, const Vertex& b)
{
    Vertex c;
    c.Position = a.Position - b.Position;
    c.Normal = a.Normal - b.Normal;
    c.TexCoord = a.TexCoord - b.TexCoord;
    c.LightMapUV = a.LightMapUV - b.LightMapUV;
    c.Tangent = a.Tangent - b.Tangent;
    c.Bitangent = a.Bitangent - b.Bitangent;
    return c;
}

inline Vertex operator*(const Vertex& a, float b)
{
    Vertex c;
    c.Position = a.Position * b;
    c.Normal = a.Normal * b;
    c.TexCoord = a.TexCoord * b;
    c.LightMapUV = a.LightMapUV * b;
    c.Tangent = a.Tangent * b;
    c.Bitangent = a.Bitangent * b;
    return c;
}

// Interpolates 3 vertex values using barycentric coordinates
template<typename T> T BarycentricLerp(const T& v0, const T& v1, const T& v2, float u, float v)
{
    return v0 + (v1 - v0) * u + (v2 - v0) * v;
}

// Interpolates triangle vertex values using the barycentric coordinates from a BVH hit result
template<typename T> T TriangleLerp(const EmbreeRay& ray, const BVHData& bvhData, const std::vector<T>& vertexData)
{
    const uint64 triangleIdx = ray.primID;
    const Uint3& triangle = bvhData.Triangles[triangleIdx];
    const T& v0 = vertexData[triangle.x];
    const T& v1 = vertexData[triangle.y];
    const T& v2 = vertexData[triangle.z];

    return BarycentricLerp(v0, v1, v2, ray.u, ray.v);
}

// Returns the direct sun radiance for a direction on the skydome
static Float3 SampleSun(Float3 sampleDir)
{
    Float3 res = 0.0f;
    if(AppSettings::EnableSun)
    {
        float cosSunAngularRadius = std::cos(DegToRad(AppSettings::SunSize));
        Float3 sunDir = Float3::Normalize(AppSettings::SunDirection);
        float cosGamma = Float3::Dot(sunDir, sampleDir);
        if(cosGamma >= cosSunAngularRadius)
            res = AppSettings::SunLuminance();
    }

    return res;
}

// Checks if a hit triangle is back-facing
static bool IsTriangleBackFacing(const EmbreeRay& ray, const BVHData& bvhData)
{
    // Compute the triangle normal
    const uint64 triangleIdx = ray.primID;
    const Uint3& triangle = bvhData.Triangles[triangleIdx];
    const Float3& v0 = bvhData.Vertices[triangle.x].Position;
    const Float3& v1 = bvhData.Vertices[triangle.y].Position;
    const Float3& v2 = bvhData.Vertices[triangle.z].Position;

    Float3 triNml = Float3::Normalize(Float3::Cross(v2 - v0, v1 - v0));
    return Float3::Dot(triNml, ray.Direction()) <= 0.0f;
}

// Returns true the the ray is occluded by a triangle
static bool Occluded(RTCScene scene, const Float3& position, const Float3& direction, float nearDist, float farDist)
{
    EmbreeRay ray(position, direction, nearDist, farDist);
    rtcOccluded(scene, ray);
    return ray.Hit();
}

// Calculates diffuse and specular from a spherical area light
static Float3 SampleSphericalAreaLight(const Float3& position, const Float3& normal, RTCScene scene,
                                       const Float3& diffuseAlbedo, const Float3& cameraPos,
                                       bool includeSpecular, Float3 specAlbedo, float roughness,
                                       float u1, float u2, float lightRadius,
                                       const Float3& lightPos, const Float3& lightColor,
                                       Float3& irradiance, Float3& sampleDir)
{
    const float radius2 = lightRadius * lightRadius;
    const float invPDF = 2.0f * Pi * radius2;

    Float3 result = 0.0f;
    Float3 areaLightIrradiance = 0.0f;

    float r = lightRadius;
    float x = u1;
    float y = u2;

    Float3 samplePos;
    samplePos.x = lightPos.x + 2.0f * r * std::cos(2.0f * Pi * y) * std::sqrt(x * (1.0f - x));
    samplePos.y = lightPos.y + 2.0f * r * std::sin(2.0f * Pi * y) * std::sqrt(x * (1.0f - x));
    samplePos.z = lightPos.z + r * (1.0f - 2.0f * x);

    sampleDir = samplePos - position;
    float sampleDirLen = Float3::Length(sampleDir);
    bool visible = false;
    if(sampleDirLen > 0.0f)
    {
        sampleDir /= sampleDirLen;

        visible = (AppSettings::EnableAreaLightShadows == false) || (Occluded(scene, position, sampleDir, 0.1f, sampleDirLen) == false);
    }

    float areaNDotL = std::abs(Float3::Dot(sampleDir, Float3::Normalize(samplePos - lightPos)));
    float sDotN = Saturate(Float3::Dot(sampleDir, normal));

    float invRSqr = 1.0f / (sampleDirLen * sampleDirLen);

    float attenuation = areaNDotL * invRSqr;
    if(attenuation && visible)
    {
        Float3 sampleIrradiance = Saturate(Float3::Dot(normal, sampleDir)) * lightColor * attenuation;
        Float3 sample = CalcLighting(normal, sampleIrradiance, sampleDir, diffuseAlbedo, position,
                                     cameraPos, roughness, includeSpecular, specAlbedo);
        result = sample * invPDF;
        areaLightIrradiance = sampleIrradiance * invPDF;
    }

    irradiance += areaLightIrradiance;

    return result;
}

// Calculates diffuse and specular contribution from the area light, given a 2D random sample point
// representing a location on the surface of the light
Float3 SampleAreaLight(const Float3& position, const Float3& normal, RTCScene scene,
                       const Float3& diffuseAlbedo, const Float3& cameraPos,
                       bool includeSpecular, Float3 specAlbedo, float roughness,
                       float u1, float u2, Float3& irradiance, Float3& sampleDir)
{
    Float3 lightPos = Float3(AppSettings::AreaLightX, AppSettings::AreaLightY, AppSettings::AreaLightZ);
    return SampleSphericalAreaLight(position, normal, scene, diffuseAlbedo, cameraPos, includeSpecular,
                                    specAlbedo, roughness, u1, u2, AppSettings::AreaLightSize,
                                    lightPos, AppSettings::AreaLightColor.Value() * FP16Scale, irradiance, sampleDir);
}

// Checks to see if a ray intersects with the area light
static float AreaLightIntersection(const Float3& rayStart, const Float3& rayDir, float tStart, float tEnd)
{

    DirectX::BoundingSphere areaLightSphere;
    areaLightSphere.Center = XMFLOAT3(AppSettings::AreaLightX, AppSettings::AreaLightY, AppSettings::AreaLightZ);
    areaLightSphere.Radius = AppSettings::AreaLightSize;

    float intersectDist = FLT_MAX;
    bool intersects = areaLightSphere.Intersects(rayStart.ToSIMD(), rayDir.ToSIMD(), intersectDist);
    intersects = intersects && (intersectDist >= tStart && intersectDist <= tEnd);
    return intersects ? intersectDist : FLT_MAX;
}

// Computes the difuse and specular contribution from the sun, given a 2D random sample point
// representing a location on the surface of the light
Float3 SampleSunLight(const Float3& position, const Float3& normal, RTCScene scene,
                             const Float3& diffuseAlbedo, const Float3& cameraPos,
                             bool includeSpecular, Float3 specAlbedo, float roughness,
                             float u1, float u2, Float3& irradiance)
{
    // Treat the sun as a spherical area light that's very far away from the surface
    const float sunDistance = 1000.0f;
    const float radius = std::tan(DegToRad(AppSettings::SunSize)) * sunDistance;
    Float3 sunLuminance = AppSettings::SunLuminance();
    Float3 sunPos = position + AppSettings::SunDirection.Value() * sunDistance;
    Float3 sampleDir;
    return SampleSphericalAreaLight(position, normal, scene, diffuseAlbedo, cameraPos, includeSpecular,
                                    specAlbedo, roughness, u1, u2, radius, sunPos, sunLuminance, irradiance, sampleDir);
}

// Generates a full list of sample points for all integration types
void GenerateIntegrationSamples(IntegrationSamples& samples, uint64 sqrtNumSamples, uint64 tileSizeX, uint64 tileSizeY,
                                SampleModes sampleMode, uint64 numIntegrationTypes, Random& rng)
{
    const uint64 numSamplesPerPixel = sqrtNumSamples * sqrtNumSamples;
    const uint64 numTilePixels = tileSizeX * tileSizeY;
    const uint64 numSamplesPerTile = numSamplesPerPixel * numTilePixels;
    samples.Init(numTilePixels, numIntegrationTypes, numSamplesPerPixel);

    for(uint64 pixelIdx = 0; pixelIdx < numTilePixels; ++pixelIdx)
    {
        for(uint64 typeIdx = 0; typeIdx < numIntegrationTypes; ++typeIdx)
        {
            Float2* typeSamples = samples.GetSamplesForType(pixelIdx, typeIdx);
            if(sampleMode == SampleModes::Stratified)
            {
                GenerateStratifiedSamples2D(typeSamples, sqrtNumSamples, sqrtNumSamples, rng);
                Shuffle(typeSamples, numSamplesPerPixel, rng);
            }
            else if(sampleMode == SampleModes::UniformGrid)
            {
                GenerateGridSamples2D(typeSamples, sqrtNumSamples, sqrtNumSamples);
                Shuffle(typeSamples, numSamplesPerPixel, rng);
            }
            else if(sampleMode == SampleModes::Hammersley)
            {
                GenerateHammersleySamples2D(typeSamples, numSamplesPerPixel, typeIdx);
                Shuffle(typeSamples, numSamplesPerPixel, rng);
            }
            else if(sampleMode == SampleModes::CMJ)
            {
                GenerateCMJSamples2D(typeSamples, sqrtNumSamples, sqrtNumSamples, rng.RandomUint());
                Shuffle(typeSamples, numSamplesPerPixel, rng);
            }
            else
            {
                GenerateRandomSamples2D(typeSamples, numSamplesPerPixel, rng);
            }
        }
    }
}

// Returns the incoming radiance along the ray specified by params.RayDir, computed using unidirectional
// path tracing
Float3 PathTrace(const PathTracerParams& params, Random& randomGenerator, float& illuminance, bool& hitSky)
{
    // Initialize to the view parameters, must be reset every loop iteration
    EmbreeRay ray(params.RayStart, params.RayDir, 0.0f, params.RayLen);
    illuminance = 0.0f;
    Float3 radiance;
    Float3 irradiance;
    Float3 throughput = 1.0f;
    Float3 irrThroughput = 1.0f;

    // Keep tracing paths until we reach the specified max
    const int64 maxPathLength = params.MaxPathLength;
    for(int64 pathLength = 1; pathLength <= maxPathLength || maxPathLength == -1; ++pathLength)
    {
        const bool indirectSpecOnly = params.ViewIndirectSpecular && pathLength == 1;
        const bool indirectDiffuseOnly = params.ViewIndirectDiffuse && pathLength == 1;
        const bool enableSpecular = (params.EnableBounceSpecular || (pathLength == 1)) && params.EnableSpecular;
        const bool enableDiffuse = params.EnableDiffuse;
        const bool skipDirect = AppSettings::ShowGroundTruth && (!AppSettings::EnableDirectLighting || indirectDiffuseOnly) && (pathLength == 1);

        // See if we should randomly terminate this path using Russian Roullete
        const int32 rouletteDepth = params.RussianRouletteDepth;
        if(pathLength >= rouletteDepth && rouletteDepth != -1)
        {
            float continueProbability = std::min<float>(params.RussianRouletteProbability, ComputeLuminance(throughput));
            if(randomGenerator.RandomFloat() > continueProbability)
                break;
            throughput /= continueProbability;
            irrThroughput /= continueProbability;
        }

        // Set this to true to keep the loop going
        bool continueTracing = false;

        // Check for intersection with the scene
        rtcIntersect(params.SceneBVH->Scene, ray);
        float sceneDistance = ray.Hit() ? ray.tfar : FLT_MAX;

        Float3 rayOrigin = ray.Origin();
        Float3 rayDir = ray.Direction();

        // Check for intersection with the area light for primary rays
        float lightDistance = FLT_MAX;
        if(params.EnableDirectAreaLight && AppSettings::EnableAreaLight && pathLength == 1)
            lightDistance = AreaLightIntersection(rayOrigin, rayDir, ray.tnear, ray.tfar);

        if(lightDistance < sceneDistance)
        {
            // We hit the area light: just return the uniform radiance of the light source
            radiance = AppSettings::AreaLightColor.Value() * throughput * FP16Scale;
            irradiance = 0.0f;
        }
        else if(sceneDistance < FLT_MAX)
        {
            // We hit a triangle in the scene
            if(pathLength == maxPathLength)
            {
                // There's no point in continuing anymore, since none of our scene surfaces are emissive.
                break;
            }

            const BVHData& bvh = *params.SceneBVH;

            // Treat back-facing triangles as pure black
            if(IsTriangleBackFacing(ray, bvh))
                break;

            // Interpolate the vertex data
            Vertex hitSurface = TriangleLerp(ray, bvh, bvh.Vertices);

            hitSurface.Normal = Float3::Normalize(hitSurface.Normal);
            hitSurface.Tangent = Float3::Normalize(hitSurface.Tangent);
            hitSurface.Bitangent = Float3::Normalize(hitSurface.Bitangent);

            // Look up the material data
            const uint64 materialIdx = bvh.MaterialIndices[ray.primID];

            Float3 albedo = 1.0f;
            if(AppSettings::EnableAlbedoMaps && !indirectDiffuseOnly)
                albedo = SampleTexture2D(hitSurface.TexCoord, bvh.MaterialDiffuseMaps[materialIdx]);

            Float3x3 tangentToWorld;
            tangentToWorld.SetXBasis(hitSurface.Tangent);
            tangentToWorld.SetYBasis(hitSurface.Bitangent);
            tangentToWorld.SetZBasis(hitSurface.Normal);

            // Normal mapping
            Float3 normal = hitSurface.Normal;
            const auto& normalMap = bvh.MaterialNormalMaps[materialIdx];
            if(AppSettings::EnableNormalMaps && normalMap.Texels.size() > 0)
            {
                normal = Float3(SampleTexture2D(hitSurface.TexCoord, normalMap));
                normal = normal * 2.0f - 1.0f;
                normal.z = std::sqrt(1.0f - Saturate(normal.x * normal.x + normal.y * normal.y));
                normal = Lerp(Float3(0.0f, 0.0f, 1.0f), normal, AppSettings::NormalMapIntensity);
                normal = Float3::Normalize(Float3::Transform(normal, tangentToWorld));
            }

            tangentToWorld.SetZBasis(normal);

            float sqrtRoughness = Float3(SampleTexture2D(hitSurface.TexCoord, bvh.MaterialRoughnessMaps[materialIdx])).x;
            float metallic =  Float3(SampleTexture2D(hitSurface.TexCoord, bvh.MaterialMetallicMaps[materialIdx])).x;
            metallic = Saturate(metallic + AppSettings::MetallicOffset);

            Float3 diffuseAlbedo = Lerp(albedo, Float3(0.0f), metallic) * AppSettings::DiffuseAlbedoScale;
            Float3 specAlbedo = Lerp(Float3(0.03f), albedo, metallic);
            sqrtRoughness *= AppSettings::RoughnessScale;
            if(AppSettings::RoughnessOverride >= 0.01f)
                sqrtRoughness = AppSettings::RoughnessOverride;

            sqrtRoughness = Saturate(sqrtRoughness);
            float roughness = sqrtRoughness * sqrtRoughness;

            diffuseAlbedo *= enableDiffuse ? 1.0f : 0.0f;

            if(indirectSpecOnly == false)
            {
                // Compute direct lighting from the sun
                Float3 directLighting;
                Float3 directIrradiance;
                if((AppSettings::EnableDirectLighting || pathLength > 1) && AppSettings::EnableSun)
                {
                    Float2 sunSample = params.SampleSet->Sun();
                    if(pathLength > 1)
                        sunSample = randomGenerator.RandomFloat2();
                    Float3 sunDirectLighting = SampleSunLight(hitSurface.Position, normal, bvh.Scene, diffuseAlbedo,
                                                     rayOrigin, enableSpecular, specAlbedo, roughness,
                                                     sunSample.x, sunSample.y, directIrradiance);
                    if(!skipDirect || AppSettings::BakeDirectSunLight)
                        directLighting += sunDirectLighting;
                }

                // Compute direct lighting from the area light
                if(AppSettings::EnableAreaLight)
                {
                    Float2 areaLightSample = params.SampleSet->AreaLight();
                    if(pathLength > 1)
                        areaLightSample = randomGenerator.RandomFloat2();
                    Float3 areaLightSampleDir;
                    Float3 areaLightDirectLighting = SampleAreaLight(hitSurface.Position, normal, bvh.Scene, diffuseAlbedo,
                                                     rayOrigin, enableSpecular, specAlbedo, roughness,
                                                     areaLightSample.x, areaLightSample.y, directIrradiance, areaLightSampleDir);
                    if(!skipDirect || AppSettings::BakeDirectAreaLight)
                        directLighting += areaLightDirectLighting;
                }

                radiance += directLighting * throughput;
                irradiance += directIrradiance * irrThroughput;
            }

            // Pick a new path, using MIS to sample both our diffuse and specular BRDF's
            if(AppSettings::EnableIndirectLighting || params.ViewIndirectSpecular)
            {
                const bool enableDiffuseSampling = metallic < 1.0f && AppSettings::EnableIndirectDiffuse && enableDiffuse && indirectSpecOnly == false;
                const bool enableSpecularSampling = enableSpecular && AppSettings::EnableIndirectSpecular && !indirectDiffuseOnly;
                if(enableDiffuseSampling || enableSpecularSampling)
                {
                    // Randomly select if we should sample our diffuse BRDF, or our specular BRDF
                    Float2 brdfSample = params.SampleSet->BRDF();
                    if(pathLength > 1)
                        brdfSample = randomGenerator.RandomFloat2();

                    float selector = brdfSample.x;
                    if(enableSpecularSampling == false)
                        selector = 0.0f;
                    else if(enableDiffuseSampling == false)
                        selector = 1.0f;

                    Float3 sampleDir;
                    Float3 v = Float3::Normalize(rayOrigin - hitSurface.Position);

                    if(selector < 0.5f)
                    {
                        // We're sampling the diffuse BRDF, so sample a cosine-weighted hemisphere
                        if(enableSpecularSampling)
                            brdfSample.x *= 2.0f;
                        sampleDir = SampleCosineHemisphere(brdfSample.x, brdfSample.y);
                        sampleDir = Float3::Normalize(Float3::Transform(sampleDir, tangentToWorld));
                    }
                    else
                    {
                        // We're sampling the GGX specular BRDF
                        if(enableDiffuseSampling)
                            brdfSample.x = (brdfSample.x - 0.5f) * 2.0f;
                        sampleDir = SampleDirectionGGX(v, normal, roughness, tangentToWorld, brdfSample.x, brdfSample.y);
                    }

                    Float3 h = Float3::Normalize(v + sampleDir);
                    float nDotL = Saturate(Float3::Dot(sampleDir, normal));

                    float diffusePDF = enableDiffuseSampling ? nDotL * InvPi : 0.0f;
                    float specularPDF = enableSpecularSampling ? GGX_PDF(normal, h, v, roughness) : 0.0f;
                    float pdf = diffusePDF + specularPDF;
                    if(enableDiffuseSampling && enableSpecularSampling)
                        pdf *= 0.5f;

                    if(nDotL > 0.0f && pdf > 0.0f && Float3::Dot(sampleDir, hitSurface.Normal) > 0.0f)
                    {
                        // Compute both BRDF's
                        Float3 brdf = 0.0f;
                        if(enableDiffuseSampling)
                            brdf += ((AppSettings::ShowGroundTruth && params.ViewIndirectDiffuse && pathLength == 1) ? Float3(1, 1, 1) : diffuseAlbedo) * InvPi;

                        if(enableSpecularSampling)
                        {
                            float spec = GGX_Specular(roughness, normal, h, v, sampleDir);
                            brdf += Fresnel(specAlbedo, h, sampleDir) * spec;
                        }

                        throughput *= brdf * nDotL / pdf;
                        irrThroughput *= nDotL / pdf;

                        // Generate the ray for the new path
                        ray = EmbreeRay(hitSurface.Position, sampleDir, 0.001f, FLT_MAX);

                        continueTracing = true;
                    }
                }
            }
        }
        else {
            // We hit the sky, so we'll sample the sky radiance and then bail out
            hitSky = true;

            if (AppSettings::SkyMode == SkyModes::Procedural)
            {
                Float3 skyRadiance = Skybox::SampleSky(*params.SkyCache, rayDir);
                if (pathLength == 1 && params.EnableDirectSun)
                    skyRadiance += SampleSun(rayDir);
                radiance += skyRadiance * throughput;
                irradiance += skyRadiance * irrThroughput;
            }
            else if (AppSettings::SkyMode == SkyModes::Simple)
            {
                Float3 skyRadiance = AppSettings::SkyColor.Value() * FP16Scale;
                if (pathLength == 1 && params.EnableDirectSun)
                    skyRadiance += SampleSun(rayDir);
                radiance += skyRadiance * throughput;
                irradiance += skyRadiance * irrThroughput;
            }
            else if (AppSettings::SkyMode >= AppSettings::CubeMapStart)
            {
                Float3 cubeMapRadiance = SampleCubemap(rayDir, params.EnvMaps[AppSettings::SkyMode - AppSettings::CubeMapStart]);
                radiance += cubeMapRadiance * throughput;
                irradiance += cubeMapRadiance * irrThroughput;
            }
        }

        if(continueTracing == false)
            break;
    }

    illuminance = ComputeLuminance(irradiance);
    return radiance;
}