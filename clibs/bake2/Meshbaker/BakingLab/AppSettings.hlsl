cbuffer AppSettings : register(b7)
{
    bool EnableSun;
    bool SunAreaLightApproximation;
    bool BakeDirectSunLight;
    float3 SunTintColor;
    float SunIntensityScale;
    float SunSize;
    int SunDirType;
    float3 SunDirection;
    float SunAzimuth;
    float SunElevation;
    bool EnableAreaLight;
    float3 AreaLightColor;
    float AreaLightSize;
    float AreaLightX;
    float AreaLightY;
    float AreaLightZ;
    float AreaLightShadowBias;
    bool BakeDirectAreaLight;
    bool EnableAreaLightShadows;
    int ExposureMode;
    float ManualExposure;
    float FilmSize;
    float FocalLength;
    float FocusDistance;
    int NumBlades;
    float KeyValue;
    float AdaptationRate;
    float ApertureFNumber;
    float ApertureWidth;
    float ShutterSpeedValue;
    float ISO;
    float BokehPolygonAmount;
    int ToneMappingMode;
    float WhitePoint_Hejl;
    float ShoulderStrength;
    float LinearStrength;
    float LinearAngle;
    float ToeStrength;
    float WhitePoint_Hable;
    int MSAAMode;
    int FilterType;
    float FilterSize;
    float GaussianSigma;
    int SGDiffuseMode;
    int SGSpecularMode;
    int SH4DiffuseMode;
    int SHSpecularMode;
    int LightMapResolution;
    int BakeMode;
    int SolveMode;
    bool WorldSpaceBake;
    bool EnableDiffuse;
    bool EnableSpecular;
    bool EnableDirectLighting;
    bool EnableIndirectLighting;
    bool EnableIndirectDiffuse;
    bool EnableIndirectSpecular;
    bool EnableAlbedoMaps;
    bool EnableNormalMaps;
    float NormalMapIntensity;
    float DiffuseAlbedoScale;
    float RoughnessScale;
    float MetallicOffset;
    float BloomExposure;
    float BloomMagnitude;
    float BloomBlurSigma;
    bool ViewIndirectDiffuse;
    bool ViewIndirectSpecular;
    float RoughnessOverride;
}

static const int SunDirectionTypes_UnitVector = 0;
static const int SunDirectionTypes_HorizontalCoordSystem = 1;

static const int SkyModes_None = 0;
static const int SkyModes_Procedural = 1;
static const int SkyModes_Simple = 2;
static const int SkyModes_CubeMapEnnis = 3;
static const int SkyModes_CubeMapGraceCathedral = 4;
static const int SkyModes_CubeMapUffizi = 5;

static const int LightUnits_Luminance = 0;
static const int LightUnits_Illuminance = 1;
static const int LightUnits_LuminousPower = 2;
static const int LightUnits_EV100 = 3;

static const int ExposureModes_ManualSimple = 0;
static const int ExposureModes_Manual_SBS = 1;
static const int ExposureModes_Manual_SOS = 2;
static const int ExposureModes_Automatic = 3;

static const int FStops_FStop1Point8 = 0;
static const int FStops_FStop2Point0 = 1;
static const int FStops_FStop2Point2 = 2;
static const int FStops_FStop2Point5 = 3;
static const int FStops_FStop2Point8 = 4;
static const int FStops_FStop3Point2 = 5;
static const int FStops_FStop3Point5 = 6;
static const int FStops_FStop4Point0 = 7;
static const int FStops_FStop4Point5 = 8;
static const int FStops_FStop5Point0 = 9;
static const int FStops_FStop5Point6 = 10;
static const int FStops_FStop6Point3 = 11;
static const int FStops_FStop7Point1 = 12;
static const int FStops_FStop8Point0 = 13;
static const int FStops_FStop9Point0 = 14;
static const int FStops_FStop10Point0 = 15;
static const int FStops_FStop11Point0 = 16;
static const int FStops_FStop13Point0 = 17;
static const int FStops_FStop14Point0 = 18;
static const int FStops_FStop16Point0 = 19;
static const int FStops_FStop18Point0 = 20;
static const int FStops_FStop20Point0 = 21;
static const int FStops_FStop22Point0 = 22;

static const int ISORatings_ISO100 = 0;
static const int ISORatings_ISO200 = 1;
static const int ISORatings_ISO400 = 2;
static const int ISORatings_ISO800 = 3;

static const int ShutterSpeeds_ShutterSpeed1Over1 = 0;
static const int ShutterSpeeds_ShutterSpeed1Over2 = 1;
static const int ShutterSpeeds_ShutterSpeed1Over4 = 2;
static const int ShutterSpeeds_ShutterSpeed1Over8 = 3;
static const int ShutterSpeeds_ShutterSpeed1Over15 = 4;
static const int ShutterSpeeds_ShutterSpeed1Over30 = 5;
static const int ShutterSpeeds_ShutterSpeed1Over60 = 6;
static const int ShutterSpeeds_ShutterSpeed1Over125 = 7;
static const int ShutterSpeeds_ShutterSpeed1Over250 = 8;
static const int ShutterSpeeds_ShutterSpeed1Over500 = 9;
static const int ShutterSpeeds_ShutterSpeed1Over1000 = 10;
static const int ShutterSpeeds_ShutterSpeed1Over2000 = 11;
static const int ShutterSpeeds_ShutterSpeed1Over4000 = 12;

static const int ToneMappingModes_FilmStock = 0;
static const int ToneMappingModes_Linear = 1;
static const int ToneMappingModes_ACES = 2;
static const int ToneMappingModes_Hejl2015 = 3;
static const int ToneMappingModes_Hable = 4;

static const int MSAAModes_MSAANone = 0;
static const int MSAAModes_MSAA2x = 1;
static const int MSAAModes_MSAA4x = 2;
static const int MSAAModes_MSAA8x = 3;

static const int FilterTypes_Box = 0;
static const int FilterTypes_Triangle = 1;
static const int FilterTypes_Gaussian = 2;
static const int FilterTypes_BlackmanHarris = 3;
static const int FilterTypes_Smoothstep = 4;
static const int FilterTypes_BSpline = 5;

static const int JitterModes_None = 0;
static const int JitterModes_Uniform2x = 1;
static const int JitterModes_Hammersley4x = 2;
static const int JitterModes_Hammersley8x = 3;
static const int JitterModes_Hammersley16x = 4;

static const int SGDiffuseModes_InnerProduct = 0;
static const int SGDiffuseModes_Punctual = 1;
static const int SGDiffuseModes_Fitted = 2;

static const int SGSpecularModes_Punctual = 0;
static const int SGSpecularModes_SGWarp = 1;
static const int SGSpecularModes_ASGWarp = 2;

static const int SH4DiffuseModes_Convolution = 0;
static const int SH4DiffuseModes_Geomerics = 1;

static const int SHSpecularModes_Convolution = 0;
static const int SHSpecularModes_DominantDirection = 1;
static const int SHSpecularModes_Punctual = 2;
static const int SHSpecularModes_Prefiltered = 3;

static const int SampleModes_Random = 0;
static const int SampleModes_Stratified = 1;
static const int SampleModes_Hammersley = 2;
static const int SampleModes_UniformGrid = 3;
static const int SampleModes_CMJ = 4;

static const int BakeModes_Diffuse = 0;
static const int BakeModes_Directional = 1;
static const int BakeModes_DirectionalRGB = 2;
static const int BakeModes_HL2 = 3;
static const int BakeModes_SH4 = 4;
static const int BakeModes_SH9 = 5;
static const int BakeModes_H4 = 6;
static const int BakeModes_H6 = 7;
static const int BakeModes_SG5 = 8;
static const int BakeModes_SG6 = 9;
static const int BakeModes_SG9 = 10;
static const int BakeModes_SG12 = 11;

static const int SolveModes_Projection = 0;
static const int SolveModes_SVD = 1;
static const int SolveModes_NNLS = 2;
static const int SolveModes_RunningAverage = 3;
static const int SolveModes_RunningAverageNN = 4;

static const int Scenes_Box = 0;
static const int Scenes_WhiteRoom = 1;
static const int Scenes_Sponza = 2;

static const float BaseSunSize = 0.2700f;
static const int MaxSGCount = 12;
static const int MaxBasisCount = 12;
