#include "Setting.h"
#include "Graphics/Sampling.h"
#include "Graphics/Spectrum.h"
#include "Graphics/Constants.h"
#include "3rd/HosekSky/ArHosekSkyModel.h"

#include "glm/gtx/compatibility.hpp"

namespace Setting{
    BakeModes BakeMode = BakeModes::NumValues;
    SolveModes SolveMode = SolveModes::NumValues;
    bool EnableAlbedoMaps = true;
    bool EnableSun = true;
    glm::vec3 SunDirection = glm::vec3(0.f, 0.f, 1.f);
    float SunIntensityScale = 1.f;
    float Turbidity = 0.f;
    glm::vec3 SunTintColor = glm::vec4(0.f, 0.f, 0.f, 0.f);
    float SunSize = 1.f;
    bool  normalizeIntensity = 0;

    bool EnableAreaLightShadows = false;

    glm::vec3 GroundAlbedo = glm::vec3(0.f, 0.f, 0.f);

    static float IlluminanceIntegral(float theta)
    {
        float cosTheta = std::cos(theta);
        return Pi * (1.0f - (cosTheta * cosTheta));
    }

    glm::vec3 SunLuminance(bool& cached)
    {
        glm::vec3 sunDirection = Setting::SunDirection;
        sunDirection.y = Graphics::Saturate(sunDirection.y);
        sunDirection = glm::normalize(sunDirection);
        const float turbidity = glm::clamp(Setting::Turbidity, 1.0f, 32.0f);
        const float intensityScale = Setting::SunIntensityScale;
        const glm::vec3 tintColor = Setting::SunTintColor;
        const float sunSize = Setting::SunSize;

        static float turbidityCache = 2.0f;
        static glm::vec3 sunDirectionCache = glm::vec3(-0.579149902f, 0.754439294f, -0.308879942f);
        static glm::vec3 luminanceCache = glm::vec3(1.61212531e+009f, 1.36822630e+009f, 1.07235315e+009f) * FP16Scale;
        static glm::vec3 sunTintCache = glm::vec3(1.0f, 1.0f, 1.0f);
        static float sunIntensityCache = 1.0f;
        static bool normalizeCache = false;
        static float sunSizeCache = Setting::BaseSunSize;

        if(turbidityCache == turbidity && sunDirection == sunDirectionCache
            && intensityScale == sunIntensityCache && tintColor == sunTintCache
            && normalizeCache == normalizeIntensity && sunSize == sunSizeCache)
        {
            cached = true;
            return luminanceCache;
        }

        cached = false;

        float thetaS = std::acos(1.0f - sunDirection.y);
        float elevation = Pi_2 - thetaS;

        // Get the sun's luminance, then apply tint and scale factors
        glm::vec3 sunLuminance;

        // For now, we'll compute an average luminance value from Hosek solar radiance model, even though
        // we could compute illuminance directly while we're sampling the disk
        Graphics::SampledSpectrum groundAlbedoSpectrum = Graphics::SampledSpectrum::FromRGB(Setting::GroundAlbedo);
        Graphics::SampledSpectrum solarRadiance;

        const uint64_t NumDiscSamples = 8;
        for(uint64_t x = 0; x < NumDiscSamples; ++x)
        {
            for(uint64_t y = 0; y < NumDiscSamples; ++y)
            {
                float u = (x + 0.5f) / NumDiscSamples;
                float v = (y + 0.5f) / NumDiscSamples;
                glm::vec2 discSamplePos = Graphics::SquareToConcentricDiskMapping(u, v);

                float theta = elevation + discSamplePos.y * glm::radians(Setting::BaseSunSize);
                float gamma = discSamplePos.x * glm::radians(Setting::BaseSunSize);

                for(int32_t i = 0; i < Graphics::NumSpectralSamples; ++i)
                {
                    ArHosekSkyModelState* skyState = arhosekskymodelstate_alloc_init(elevation, turbidity, groundAlbedoSpectrum[i]);
                    float wavelength = glm::lerp(float(Graphics::SampledLambdaStart), float(Graphics::SampledLambdaEnd), i / float(Graphics::NumSpectralSamples));

                    solarRadiance[i] = float(arhosekskymodel_solar_radiance(skyState, theta, gamma, wavelength));

                    arhosekskymodelstate_free(skyState);
                    skyState = nullptr;
                }

                glm::vec3 sampleRadiance = solarRadiance.ToRGB() * FP16Scale;
                sunLuminance += sampleRadiance;
            }
        }

        // Account for luminous efficiency, coordinate system scaling, and sample averaging
        sunLuminance *= 683.0f * 100.0f * (1.0f / NumDiscSamples) * (1.0f / NumDiscSamples);

        sunLuminance = sunLuminance * tintColor;
        sunLuminance = sunLuminance * intensityScale;

        if(normalizeIntensity)
        {
            // Normalize so that the intensity stays the same even when the sun is bigger or smaller
            const float baseIntegral = IlluminanceIntegral(glm::radians(Setting::BaseSunSize));
            const float currIntegral = IlluminanceIntegral(glm::radians(Setting::SunSize));
            sunLuminance *= (baseIntegral / currIntegral);
        }

        turbidityCache = turbidity;
        sunDirectionCache = sunDirection;
        luminanceCache = sunLuminance;
        sunIntensityCache = intensityScale;
        sunTintCache = tintColor;
        normalizeCache = normalizeIntensity;
        sunSizeCache = sunSize;

        return sunLuminance;
    }


    glm::vec3 SunLuminance()
    {
        bool cached = false;
        return SunLuminance(cached);
    }

    glm::vec3 SunIlluminance()
    {
        glm::vec3 sunLuminance = SunLuminance();

        // Compute partial integral over the hemisphere in order to compute illuminance
        float theta = glm::radians(Setting::SunSize);
        float integralFactor = IlluminanceIntegral(theta);

        return sunLuminance * integralFactor;
    }
}