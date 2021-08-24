#include "Setting.h"
#include "Graphics/Constants.h"

namespace Setting{
    BakeModes BakeMode = BakeModes::NumValues;
    SolveModes SolveMode = SolveModes::NumValues;
    bool EnableAlbedoMaps = true;
    bool EnableSun = true;

    glm::vec3 SunLuminance(bool& cached)
    {
        glm::vec3 sunDirection = AppSettings::SunDirection;
        sunDirection.y = Saturate(sunDirection.y);
        sunDirection = glm::vec3::Normalize(sunDirection);
        const float turbidity = Clamp(AppSettings::Turbidity.Value(), 1.0f, 32.0f);
        const float intensityScale = AppSettings::SunIntensityScale;
        const glm::vec3 tintColor = AppSettings::SunTintColor;
        const bool32 normalizeIntensity = AppSettings::NormalizeSunIntensity;
        const float sunSize = AppSettings::SunSize;

        static float turbidityCache = 2.0f;
        static glm::vec3 sunDirectionCache = glm::vec3(-0.579149902f, 0.754439294f, -0.308879942f);
        static glm::vec3 luminanceCache = glm::vec3(1.61212531e+009f, 1.36822630e+009f, 1.07235315e+009f) * FP16Scale;
        static glm::vec3 sunTintCache = glm::vec3(1.0f, 1.0f, 1.0f);
        static float sunIntensityCache = 1.0f;
        static bool32 normalizeCache = false;
        static float sunSizeCache = AppSettings::BaseSunSize;

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
        SampledSpectrum groundAlbedoSpectrum = SampledSpectrum::FromRGB(GroundAlbedo);
        SampledSpectrum solarRadiance;

        const uint64 NumDiscSamples = 8;
        for(uint64 x = 0; x < NumDiscSamples; ++x)
        {
            for(uint64 y = 0; y < NumDiscSamples; ++y)
            {
                float u = (x + 0.5f) / NumDiscSamples;
                float v = (y + 0.5f) / NumDiscSamples;
                Float2 discSamplePos = SquareToConcentricDiskMapping(u, v);

                float theta = elevation + discSamplePos.y * DegToRad(AppSettings::BaseSunSize);
                float gamma = discSamplePos.x * DegToRad(AppSettings::BaseSunSize);

                for(int32 i = 0; i < NumSpectralSamples; ++i)
                {
                    ArHosekSkyModelState* skyState = arhosekskymodelstate_alloc_init(elevation, turbidity, groundAlbedoSpectrum[i]);
                    float wavelength = Lerp(float(SampledLambdaStart), float(SampledLambdaEnd), i / float(NumSpectralSamples));

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
            const float baseIntegral = IlluminanceIntegral(DegToRad(AppSettings::BaseSunSize));
            const float currIntegral = IlluminanceIntegral(DegToRad(AppSettings::SunSize));
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

    static float IlluminanceIntegral(float theta)
    {
        float cosTheta = std::cos(theta);
        return Pi * (1.0f - (cosTheta * cosTheta));
    }

    glm::vec3 SunIlluminance()
    {
        glm::vec3 sunLuminance = SunLuminance();

        // Compute partial integral over the hemisphere in order to compute illuminance
        float theta = DegToRad(Setting::SunSize);
        float integralFactor = IlluminanceIntegral(theta);

        return sunLuminance * integralFactor;
    }
}