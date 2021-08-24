#pragma once

#include <PCH.h>
#include <Settings.h>
#include <Graphics\GraphicsTypes.h>

using namespace SampleFramework11;

enum class SunDirectionTypes
{
    UnitVector = 0,
    HorizontalCoordSystem = 1,

    NumValues
};

typedef EnumSettingT<SunDirectionTypes> SunDirectionTypesSetting;

enum class SkyModes
{
    None = 0,
    Procedural = 1,
    Simple = 2,
    CubeMapEnnis = 3,
    CubeMapGraceCathedral = 4,
    CubeMapUffizi = 5,

    NumValues
};

typedef EnumSettingT<SkyModes> SkyModesSetting;

enum class LightUnits
{
    Luminance = 0,
    Illuminance = 1,
    LuminousPower = 2,
    EV100 = 3,

    NumValues
};

typedef EnumSettingT<LightUnits> LightUnitsSetting;

enum class ExposureModes
{
    ManualSimple = 0,
    Manual_SBS = 1,
    Manual_SOS = 2,
    Automatic = 3,

    NumValues
};

typedef EnumSettingT<ExposureModes> ExposureModesSetting;

enum class FStops
{
    FStop1Point8 = 0,
    FStop2Point0 = 1,
    FStop2Point2 = 2,
    FStop2Point5 = 3,
    FStop2Point8 = 4,
    FStop3Point2 = 5,
    FStop3Point5 = 6,
    FStop4Point0 = 7,
    FStop4Point5 = 8,
    FStop5Point0 = 9,
    FStop5Point6 = 10,
    FStop6Point3 = 11,
    FStop7Point1 = 12,
    FStop8Point0 = 13,
    FStop9Point0 = 14,
    FStop10Point0 = 15,
    FStop11Point0 = 16,
    FStop13Point0 = 17,
    FStop14Point0 = 18,
    FStop16Point0 = 19,
    FStop18Point0 = 20,
    FStop20Point0 = 21,
    FStop22Point0 = 22,

    NumValues
};

typedef EnumSettingT<FStops> FStopsSetting;

enum class ISORatings
{
    ISO100 = 0,
    ISO200 = 1,
    ISO400 = 2,
    ISO800 = 3,

    NumValues
};

typedef EnumSettingT<ISORatings> ISORatingsSetting;

enum class ShutterSpeeds
{
    ShutterSpeed1Over1 = 0,
    ShutterSpeed1Over2 = 1,
    ShutterSpeed1Over4 = 2,
    ShutterSpeed1Over8 = 3,
    ShutterSpeed1Over15 = 4,
    ShutterSpeed1Over30 = 5,
    ShutterSpeed1Over60 = 6,
    ShutterSpeed1Over125 = 7,
    ShutterSpeed1Over250 = 8,
    ShutterSpeed1Over500 = 9,
    ShutterSpeed1Over1000 = 10,
    ShutterSpeed1Over2000 = 11,
    ShutterSpeed1Over4000 = 12,

    NumValues
};

typedef EnumSettingT<ShutterSpeeds> ShutterSpeedsSetting;

enum class ToneMappingModes
{
    FilmStock = 0,
    Linear = 1,
    ACES = 2,
    Hejl2015 = 3,
    Hable = 4,

    NumValues
};

typedef EnumSettingT<ToneMappingModes> ToneMappingModesSetting;

enum class MSAAModes
{
    MSAANone = 0,
    MSAA2x = 1,
    MSAA4x = 2,
    MSAA8x = 3,

    NumValues
};

typedef EnumSettingT<MSAAModes> MSAAModesSetting;

enum class FilterTypes
{
    Box = 0,
    Triangle = 1,
    Gaussian = 2,
    BlackmanHarris = 3,
    Smoothstep = 4,
    BSpline = 5,

    NumValues
};

typedef EnumSettingT<FilterTypes> FilterTypesSetting;

enum class JitterModes
{
    None = 0,
    Uniform2x = 1,
    Hammersley4x = 2,
    Hammersley8x = 3,
    Hammersley16x = 4,

    NumValues
};

typedef EnumSettingT<JitterModes> JitterModesSetting;

enum class SGDiffuseModes
{
    InnerProduct = 0,
    Punctual = 1,
    Fitted = 2,

    NumValues
};

typedef EnumSettingT<SGDiffuseModes> SGDiffuseModesSetting;

enum class SGSpecularModes
{
    Punctual = 0,
    SGWarp = 1,
    ASGWarp = 2,

    NumValues
};

typedef EnumSettingT<SGSpecularModes> SGSpecularModesSetting;

enum class SH4DiffuseModes
{
    Convolution = 0,
    Geomerics = 1,

    NumValues
};

typedef EnumSettingT<SH4DiffuseModes> SH4DiffuseModesSetting;

enum class SHSpecularModes
{
    Convolution = 0,
    DominantDirection = 1,
    Punctual = 2,
    Prefiltered = 3,

    NumValues
};

typedef EnumSettingT<SHSpecularModes> SHSpecularModesSetting;

enum class SampleModes
{
    Random = 0,
    Stratified = 1,
    Hammersley = 2,
    UniformGrid = 3,
    CMJ = 4,

    NumValues
};

typedef EnumSettingT<SampleModes> SampleModesSetting;

enum class BakeModes
{
    Diffuse = 0,
    Directional = 1,
    DirectionalRGB = 2,
    HL2 = 3,
    SH4 = 4,
    SH9 = 5,
    H4 = 6,
    H6 = 7,
    SG5 = 8,
    SG6 = 9,
    SG9 = 10,
    SG12 = 11,

    NumValues
};

typedef EnumSettingT<BakeModes> BakeModesSetting;

enum class SolveModes
{
    Projection = 0,
    SVD = 1,
    NNLS = 2,
    RunningAverage = 3,
    RunningAverageNN = 4,

    NumValues
};

typedef EnumSettingT<SolveModes> SolveModesSetting;

enum class Scenes
{
    Box = 0,
    WhiteRoom = 1,
    Sponza = 2,

    NumValues
};

typedef EnumSettingT<Scenes> ScenesSetting;

namespace AppSettings
{
    static const float BaseSunSize = 0.2700f;
    static const int64 MaxSGCount = 12;
    static const int64 MaxBasisCount = 12;

    extern BoolSetting EnableSun;
    extern BoolSetting SunAreaLightApproximation;
    extern BoolSetting BakeDirectSunLight;
    extern ColorSetting SunTintColor;
    extern FloatSetting SunIntensityScale;
    extern FloatSetting SunSize;
    extern BoolSetting NormalizeSunIntensity;
    extern SunDirectionTypesSetting SunDirType;
    extern DirectionSetting SunDirection;
    extern FloatSetting SunAzimuth;
    extern FloatSetting SunElevation;
    extern SkyModesSetting SkyMode;
    extern ColorSetting SkyColor;
    extern FloatSetting Turbidity;
    extern ColorSetting GroundAlbedo;
    extern BoolSetting EnableAreaLight;
    extern ColorSetting AreaLightColor;
    extern FloatSetting AreaLightIlluminance;
    extern FloatSetting AreaLightLuminousPower;
    extern FloatSetting AreaLightEV100;
    extern LightUnitsSetting AreaLightUnits;
    extern FloatSetting AreaLightIlluminanceDistance;
    extern FloatSetting AreaLightSize;
    extern FloatSetting AreaLightX;
    extern FloatSetting AreaLightY;
    extern FloatSetting AreaLightZ;
    extern FloatSetting AreaLightShadowBias;
    extern BoolSetting BakeDirectAreaLight;
    extern BoolSetting EnableAreaLightShadows;
    extern ExposureModesSetting ExposureMode;
    extern FloatSetting ManualExposure;
    extern FStopsSetting ApertureSize;
    extern ISORatingsSetting ISORating;
    extern ShutterSpeedsSetting ShutterSpeed;
    extern FloatSetting FilmSize;
    extern FloatSetting FocalLength;
    extern FloatSetting FocusDistance;
    extern IntSetting NumBlades;
    extern BoolSetting EnableDOF;
    extern FloatSetting KeyValue;
    extern FloatSetting AdaptationRate;
    extern FloatSetting ApertureFNumber;
    extern FloatSetting ApertureWidth;
    extern FloatSetting ShutterSpeedValue;
    extern FloatSetting ISO;
    extern FloatSetting BokehPolygonAmount;
    extern ToneMappingModesSetting ToneMappingMode;
    extern FloatSetting WhitePoint_Hejl;
    extern FloatSetting ShoulderStrength;
    extern FloatSetting LinearStrength;
    extern FloatSetting LinearAngle;
    extern FloatSetting ToeStrength;
    extern FloatSetting WhitePoint_Hable;
    extern MSAAModesSetting MSAAMode;
    extern FilterTypesSetting FilterType;
    extern FloatSetting FilterSize;
    extern FloatSetting GaussianSigma;
    extern BoolSetting EnableTemporalAA;
    extern JitterModesSetting JitterMode;
    extern FloatSetting JitterScale;
    extern SGDiffuseModesSetting SGDiffuseMode;
    extern SGSpecularModesSetting SGSpecularMode;
    extern SH4DiffuseModesSetting SH4DiffuseMode;
    extern SHSpecularModesSetting SHSpecularMode;
    extern IntSetting LightMapResolution;
    extern IntSetting NumBakeSamples;
    extern SampleModesSetting BakeSampleMode;
    extern IntSetting MaxBakePathLength;
    extern IntSetting BakeRussianRouletteDepth;
    extern FloatSetting BakeRussianRouletteProbability;
    extern BakeModesSetting BakeMode;
    extern SolveModesSetting SolveMode;
    extern BoolSetting WorldSpaceBake;
    extern ScenesSetting CurrentScene;
    extern BoolSetting EnableDiffuse;
    extern BoolSetting EnableSpecular;
    extern BoolSetting EnableDirectLighting;
    extern BoolSetting EnableIndirectLighting;
    extern BoolSetting EnableIndirectDiffuse;
    extern BoolSetting EnableIndirectSpecular;
    extern BoolSetting EnableAlbedoMaps;
    extern BoolSetting EnableNormalMaps;
    extern FloatSetting NormalMapIntensity;
    extern FloatSetting DiffuseAlbedoScale;
    extern FloatSetting RoughnessScale;
    extern FloatSetting MetallicOffset;
    extern BoolSetting ShowGroundTruth;
    extern IntSetting NumRenderSamples;
    extern SampleModesSetting RenderSampleMode;
    extern IntSetting MaxRenderPathLength;
    extern IntSetting RenderRussianRouletteDepth;
    extern FloatSetting RenderRussianRouletteProbability;
    extern BoolSetting EnableRenderBounceSpecular;
    extern FloatSetting BloomExposure;
    extern FloatSetting BloomMagnitude;
    extern FloatSetting BloomBlurSigma;
    extern BoolSetting EnableLuminancePicker;
    extern BoolSetting ShowBakeDataVisualizer;
    extern BoolSetting ViewIndirectDiffuse;
    extern BoolSetting ViewIndirectSpecular;
    extern FloatSetting RoughnessOverride;
    extern Button SaveLightSettings;
    extern Button LoadLightSettings;
    extern Button SaveEXRScreenshot;
    extern BoolSetting ShowSunIntensity;

    struct AppSettingsCBuffer
    {
        bool32 EnableSun;
        bool32 SunAreaLightApproximation;
        bool32 BakeDirectSunLight;
        Float4Align Float3 SunTintColor;
        float SunIntensityScale;
        float SunSize;
        int32 SunDirType;
        Float4Align Float3 SunDirection;
        float SunAzimuth;
        float SunElevation;
        bool32 EnableAreaLight;
        Float4Align Float3 AreaLightColor;
        float AreaLightSize;
        float AreaLightX;
        float AreaLightY;
        float AreaLightZ;
        float AreaLightShadowBias;
        bool32 BakeDirectAreaLight;
        bool32 EnableAreaLightShadows;
        int32 ExposureMode;
        float ManualExposure;
        float FilmSize;
        float FocalLength;
        float FocusDistance;
        int32 NumBlades;
        float KeyValue;
        float AdaptationRate;
        float ApertureFNumber;
        float ApertureWidth;
        float ShutterSpeedValue;
        float ISO;
        float BokehPolygonAmount;
        int32 ToneMappingMode;
        float WhitePoint_Hejl;
        float ShoulderStrength;
        float LinearStrength;
        float LinearAngle;
        float ToeStrength;
        float WhitePoint_Hable;
        int32 MSAAMode;
        int32 FilterType;
        float FilterSize;
        float GaussianSigma;
        int32 SGDiffuseMode;
        int32 SGSpecularMode;
        int32 SH4DiffuseMode;
        int32 SHSpecularMode;
        int32 LightMapResolution;
        int32 BakeMode;
        int32 SolveMode;
        bool32 WorldSpaceBake;
        bool32 EnableDiffuse;
        bool32 EnableSpecular;
        bool32 EnableDirectLighting;
        bool32 EnableIndirectLighting;
        bool32 EnableIndirectDiffuse;
        bool32 EnableIndirectSpecular;
        bool32 EnableAlbedoMaps;
        bool32 EnableNormalMaps;
        float NormalMapIntensity;
        float DiffuseAlbedoScale;
        float RoughnessScale;
        float MetallicOffset;
        float BloomExposure;
        float BloomMagnitude;
        float BloomBlurSigma;
        bool32 ViewIndirectDiffuse;
        bool32 ViewIndirectSpecular;
        float RoughnessOverride;
    };

    extern ConstantBuffer<AppSettingsCBuffer> CBuffer;

    void Initialize(ID3D11Device* device);
    void Update();
    void UpdateCBuffer(ID3D11DeviceContext* context);
};

// ================================================================================================

enum class BRDF
{
    GGX = 0,
    Beckmann = 1,
    Velvet = 2,

    NumValues
};

namespace AppSettings
{
    const uint64 CubeMapStart = uint64(SkyModes::CubeMapEnnis);
    const uint64 NumCubeMaps = uint64(SkyModes::NumValues) - CubeMapStart;

    inline const wchar* CubeMapPaths(uint64 idx)
    {
        Assert_(idx < NumCubeMaps);

        const wchar* Paths[] =
        {
            L"..\\Content\\EnvMaps\\Ennis.dds",
            L"..\\Content\\EnvMaps\\GraceCathedral.dds",
            L"..\\Content\\EnvMaps\\Uffizi.dds",
        };
        StaticAssert_(ArraySize_(Paths) == NumCubeMaps);

        return Paths[idx];
    }

    Float3 SunLuminance();
    Float3 SunIlluminance();

    inline float ISO_()
    {
        static const float ISOValues[] =
        {
            100.0f, 200.0f, 400.0f, 800.0f
        };
        StaticAssert_(ArraySize_(ISOValues) == uint64(ISORatings::NumValues));

        return ISOValues[uint64(AppSettings::ISORating)];
    }

    inline float ApertureFNumber_()
    {
        static const float FNumbers[] =
        {
            1.8f, 2.0f, 2.2f, 2.5f, 2.8f, 3.2f, 3.5f, 4.0f, 4.5f, 5.0f, 5.6f, 6.3f, 7.1f, 8.0f,
            9.0f, 10.0f, 11.0f, 13.0f, 14.0f, 16.0f, 18.0f, 20.0f, 22.0f
        };
        StaticAssert_(ArraySize_(FNumbers) == uint64(FStops::NumValues));

        return FNumbers[uint64(AppSettings::ApertureSize)];
    }

    inline float ApertureWidth_()
    {
        return (FocalLength / ApertureFNumber_()) * 0.5f;
    }

    inline float ShutterSpeedValue_()
    {
        static const float ShutterSpeedValues[] =
        {
            1.0f / 1.0f, 1.0f / 2.0f, 1.0f / 4.0f, 1.0f / 8.0f, 1.0f / 15.0f, 1.0f / 30.0f,
            1.0f / 60.0f, 1.0f / 125.0f, 1.0f / 250.0f, 1.0f / 500.0f, 1.0f / 1000.0f, 1.0f / 2000.0f, 1.0f / 4000.0f,
        };
        StaticAssert_(ArraySize_(ShutterSpeedValues) == uint64(ShutterSpeeds::NumValues));

        return ShutterSpeedValues[uint64(AppSettings::ShutterSpeed)];
    }

    inline float VerticalFOV(float aspectRatio)
    {
        float verticalSize = FilmSize / aspectRatio;
        return 2.0f * std::atan2(verticalSize, 2.0f * FocalLength);
    }

    inline void SetFocalLengthFromVFOV(float FOV, float aspectRatio)
    {
        float fs = FilmSize.RawValue();
        float verticalSize = fs / aspectRatio;
        FocalLength.SetValue(2.0f * (verticalSize * 0.5f) / tanf(FOV * 0.5f));
    }

    inline float BokehPolygonAmount_()
    {
        return std::sqrt(Saturate((ApertureFNumber_() - 1.8f) / (5.0f - 1.8f)));
    }

    inline bool HasSunDirChanged()
    {
        return AppSettings::SunDirType.Changed() ||
               AppSettings::SunDirection.Changed() ||
               AppSettings::SunAzimuth.Changed() ||
               AppSettings::SunElevation.Changed();
    }

    inline void UpdateHorizontalCoords()
    {
        Float3 sunDir = SunDirection.Value();
        SunElevation.SetValue(RadToDeg(asin(sunDir.y)));

        float rad = atan2(sunDir.z, sunDir.x);
        if(rad < 0.0f)
            rad = 2.0f * Pi + rad;

        float deg = RadToDeg(rad);
        SunAzimuth.SetValue(deg);
    }

    inline void UpdateUnitVector()
    {
        Float3 newDir;
        newDir.x = cos(DegToRad(SunAzimuth)) * cos(DegToRad(SunElevation));
        newDir.y = sin(DegToRad(SunElevation));
        newDir.z = sin(DegToRad(SunAzimuth)) * cos(DegToRad(SunElevation));
        SunDirection.SetValue(newDir);
    }

    inline uint32 NumMSAASamples(MSAAModes mode)
    {
        static const uint32 NumSamples[uint32(MSAAModes::NumValues)] = { 1, 2, 4, 8 };
        return NumSamples[uint32(mode)];
    }

    inline uint32 NumMSAASamples()
    {
        return NumMSAASamples(MSAAMode);
    }

    inline uint64 BasisCount(uint64 bakeMode)
    {
        Assert_(bakeMode < uint64(BakeModes::NumValues));
        static const uint64 BasisCounts[] = { 1, 2, 4, 3, 4, 9, 4, 6, 5, 6, 9, 12 };
        StaticAssert_(ArraySize_(BasisCounts) == uint64(BakeModes::NumValues));
        Assert_(BasisCounts[bakeMode] <= MaxBasisCount);
        return BasisCounts[bakeMode];
    }

    inline uint64 BasisCount(BakeModes bakeMode)
    {
        return BasisCount(uint64(bakeMode));
    }

    inline uint64 BasisCount()
    {
        return BasisCount(uint64(BakeMode));
    }

    inline uint64 SGCount(BakeModes bakeMode)
    {
        Assert_(uint64(bakeMode) < uint64(BakeModes::NumValues));
        if(uint64(bakeMode) >= uint64(BakeModes::SG5))
            return BasisCount(bakeMode);
        else
            return 0;
    }

    inline uint64 SGCount()
    {
        return SGCount(BakeMode);
    }

    inline bool SupportsProgressiveIntegration(BakeModes bakeMode, SolveModes solveMode)
    {
        if((bakeMode == BakeModes::Directional) || (bakeMode == BakeModes::DirectionalRGB) || (SGCount(bakeMode) > 0 && (solveMode == SolveModes::SVD || solveMode == SolveModes::NNLS)))
            return false;
        else
            return true;
    }

    void UpdateUI();
}