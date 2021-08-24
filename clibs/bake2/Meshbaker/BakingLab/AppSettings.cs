//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

enum SunDirectionTypes
{
    [EnumLabel("Unit Vector")]
    UnitVector,

    [EnumLabel("Horizontal Coordinate System")]
    HorizontalCoordSystem,
}

enum SkyModes
{
    [EnumLabel("None")]
    None = 0,

    [EnumLabel("Procedural")]
    Procedural,

    [EnumLabel("Simple")]
    Simple,

    [EnumLabel("Ennis")]
    CubeMapEnnis,

    [EnumLabel("Grace Cathedral")]
    CubeMapGraceCathedral,

    [EnumLabel("Uffizi Cross")]
    CubeMapUffizi
}

enum ToneMappingModes
{
    [EnumLabel("Film Stock")]
    FilmStock,

    [EnumLabel("Linear")]
    Linear,

    [EnumLabel("ACES sRGB Monitor")]
    ACES,

    [EnumLabel("Hejl 2015")]
    Hejl2015,

    [EnumLabel("Hable (Uncharted2)")]
    Hable,
}

enum ExposureModes
{
    [EnumLabel("Manual (Simple)")]
    ManualSimple = 0,

    [EnumLabel("Manual (SBS)")]
    Manual_SBS = 1,

    [EnumLabel("Manual (SOS)")]
    Manual_SOS = 2,

    [EnumLabel("Automatic")]
    Automatic = 3
}

enum FStops
{
    [EnumLabel("f/1.8")]
    FStop1Point8 = 0,

    [EnumLabel("f/2.0")]
    FStop2Point0,

    [EnumLabel("f/2.2")]
    FStop2Point2,

    [EnumLabel("f/2.5")]
    FStop2Point5,

    [EnumLabel("f/2.8")]
    FStop2Point8,

    [EnumLabel("f/3.2")]
    FStop3Point2,

    [EnumLabel("f/3.5")]
    FStop3Point5,

    [EnumLabel("f/4.0")]
    FStop4Point0,

    [EnumLabel("f/4.5")]
    FStop4Point5,

    [EnumLabel("f/5.0")]
    FStop5Point0,

    [EnumLabel("f/5.6")]
    FStop5Point6,

    [EnumLabel("f/6.3")]
    FStop6Point3,

    [EnumLabel("f/7.1")]
    FStop7Point1,

    [EnumLabel("f/8.0")]
    FStop8Point0,

    [EnumLabel("f/9.0")]
    FStop9Point0,

    [EnumLabel("f/10.0")]
    FStop10Point0,

    [EnumLabel("f/11.0")]
    FStop11Point0,

    [EnumLabel("f/13.0")]
    FStop13Point0,

    [EnumLabel("f/14.0")]
    FStop14Point0,

    [EnumLabel("f/16.0")]
    FStop16Point0,

    [EnumLabel("f/18.0")]
    FStop18Point0,

    [EnumLabel("f/20.0")]
    FStop20Point0,

    [EnumLabel("f/22.0")]
    FStop22Point0,
}

enum ISORatings
{
    ISO100 = 0,
    ISO200,
    ISO400,
    ISO800,
}

enum ShutterSpeeds
{
    [EnumLabel("1s")]
    ShutterSpeed1Over1 = 0,

    [EnumLabel("1/2s")]
    ShutterSpeed1Over2,

    [EnumLabel("1/4s")]
    ShutterSpeed1Over4,

    [EnumLabel("1/8s")]
    ShutterSpeed1Over8,

    [EnumLabel("1/15s")]
    ShutterSpeed1Over15,

    [EnumLabel("1/30s")]
    ShutterSpeed1Over30,

    [EnumLabel("1/60s")]
    ShutterSpeed1Over60,

    [EnumLabel("1/125s")]
    ShutterSpeed1Over125,

    [EnumLabel("1/250s")]
    ShutterSpeed1Over250,

    [EnumLabel("1/500s")]
    ShutterSpeed1Over500,

    [EnumLabel("1/1000s")]
    ShutterSpeed1Over1000,

    [EnumLabel("1/2000s")]
    ShutterSpeed1Over2000,

    [EnumLabel("1/4000s")]
    ShutterSpeed1Over4000,
}

enum SampleModes
{
    Random = 0,
    Stratified = 1,
    Hammersley = 2,
    UniformGrid = 3,
    CMJ = 4,
}

enum LightUnits
{
    Luminance = 0,
    Illuminance = 1,
    LuminousPower = 2,
    EV100 = 3
}

enum Scenes
{
    Box = 0,

    [EnumLabel("White Room")]
    WhiteRoom = 1,

    Sponza = 2,
}

enum MSAAModes
{
    [EnumLabel("None")]
    MSAANone = 0,

    [EnumLabel("2x")]
    MSAA2x,

    [EnumLabel("4x")]
    MSAA4x,

    [EnumLabel("8x")]
    MSAA8x,
}

enum FilterTypes
{
    Box = 0,
    Triangle,
    Gaussian,
    BlackmanHarris,
    Smoothstep,
    BSpline,
}

enum JitterModes
{
    None,
    Uniform2x,
    Hammersley4x,
    Hammersley8x,
    Hammersley16x,
}

enum BakeModes
{
    Diffuse = 0,

    [EnumLabel("Directional")]
    Directional,

    [EnumLabel("DirectionalRGB")]
    DirectionalRGB,

    [EnumLabel("Half-Life 2")]
    HL2,

    [EnumLabel("L1 SH")]
    SH4,

    [EnumLabel("L2 SH")]
    SH9,

    [EnumLabel("L1 H-basis")]
    H4,

    [EnumLabel("L2 H-basis")]
    H6,

    SG5,
    SG6,
    SG9,
    SG12,
}

enum SolveModes
{
    [EnumLabel("Ad-Hoc Projection")]
    Projection = 0,

    [EnumLabel("Least Squares")]
    SVD,

    [EnumLabel("Non-Negative Least Squares")]
    NNLS,

    [EnumLabel("Running Average")]
    RunningAverage,

    [EnumLabel("Running Average Non-Negative")]
    RunningAverageNN,
}

enum SGDiffuseModes
{
    InnerProduct = 0,
    Punctual,

    [EnumLabel("Fitted (Hill 16)")]
    Fitted,
}

enum SGSpecularModes
{
    Punctual = 0,

    [EnumLabel("SG Warp")]
    SGWarp,

    [EnumLabel("ASG Warp")]
    ASGWarp,
}

enum SH4DiffuseModes
{
    Convolution = 0,
    Geomerics,
}

enum SHSpecularModes
{
    Convolution = 0,
    DominantDirection,
    Punctual,
    Prefiltered,
}

public class Settings
{
    const float BaseSunSize = 0.27f;

    public class SunLight
    {
        [HelpText("Enables the sun light")]
        bool EnableSun = true;

        [HelpText("Controls whether the sun is treated as a disc area light in the real-time shader")]
        bool SunAreaLightApproximation = true;

        [HelpText("Bakes the direct contribution from the sun light into the light map")]
        bool BakeDirectSunLight = false;

        [HelpText("The color of the sun")]
        Color SunTintColor = new Color(1.0f, 1.0f, 1.0f, 1.0f);

        [HelpText("Scale the intensity of the sun")]
        [MinValue(0.0f)]
        float SunIntensityScale = 1.0f;

        [HelpText("Angular radius of the sun in degrees")]
        [MinValue(0.01f)]
        [StepSize(0.001f)]
        float SunSize = BaseSunSize;

        [UseAsShaderConstant(false)]
        bool NormalizeSunIntensity = false;

        [HelpText("Input direction type for the sun")]
        SunDirectionTypes SunDirType = SunDirectionTypes.HorizontalCoordSystem;

        [HelpText("Director of the sun")]
        Direction SunDirection = new Direction(-0.75f, 0.977f, -0.4f);

        [HelpText("Angle around the horizon")]
        [MinValue(0.0f)]
        [MaxValue(360.0f)]
        [StepSize(0.1f)]
        float SunAzimuth;

        [HelpText("Elevation of sun from ground. 0 degrees is aligned on the horizon while 90 degrees is directly overhead")]
        [MinValue(0.0f)]
        [MaxValue(90.0f)]
        [StepSize(0.1f)]
        float SunElevation;
    }

    public class Sky
    {
        [HelpText("Controls the sky used for GI baking and background rendering")]
        [UseAsShaderConstant(false)]
        SkyModes SkyMode = SkyModes.Procedural;

        [HelpText("The color of the simple sky")]
        [MinValue(0.0f)]
        [MaxValue(1000000.0f)]
        [StepSize(0.1f)]
        [HDR(true)]
        [ColorUnit(ColorUnit.Luminance)]
        [UseAsShaderConstant(false)]
        Color SkyColor = new Color(0.2f, 0.5f, 1.0f, 7000.0f);

        [MinValue(1.0f)]
        [MaxValue(10.0f)]
        [UseAsShaderConstant(false)]
        float Turbidity = 2.0f;

        [HDR(false)]
        [UseAsShaderConstant(false)]
        Color GroundAlbedo = new Color(0.5f, 0.5f, 0.5f);
    }

    [ExpandGroup(false)]
    public class AreaLight
    {
        [HelpText("Enables the area light during baking and ground truth rendering")]
        bool EnableAreaLight = false;

        [DisplayName("Color")]
        [MinValue(0.0f)]
        [StepSize(0.1f)]
        [HDR(true)]
        [ColorUnit(ColorUnit.Luminance)]
        [HelpText("The color of the area light")]
        Color AreaLightColor = new Color(1.0f, 1.0f, 1.0f, 1000000.0f);

        [DisplayName("Color Intensity (lux)")]
        [MinValue(0.0f)]
        [Visible(false)]
        [UseAsShaderConstant(false)]
        float AreaLightIlluminance = 1.0f;

        [DisplayName("Color Intensity (lm)")]
        [MinValue(0.0f)]
        [Visible(false)]
        [UseAsShaderConstant(false)]
        float AreaLightLuminousPower = 1.0f;

        [DisplayName("Color Intensity (EV100)")]
        [MinValue(-64.0f)]
        [MaxValue(64.0f)]
        [Visible(false)]
        [UseAsShaderConstant(false)]
        float AreaLightEV100 = 0.0f;

        [UseAsShaderConstant(false)]
        [DisplayName("Units")]
        LightUnits AreaLightUnits = LightUnits.Luminance;

        [DisplayName("Illuminance Distance")]
        [UseAsShaderConstant(false)]
        [Visible(false)]
        float AreaLightIlluminanceDistance = 10.0f;

        [DisplayName("Size")]
        [MinValue(0.01f)]
        [MaxValue(10.0f)]
        [StepSize(0.01f)]
        [HelpText("The radius of the area light")]
        float AreaLightSize = 0.5f;

        [DisplayName("Position X")]
        [MinValue(-100.0f)]
        [MaxValue(100.0f)]
        [StepSize(0.01f)]
        [HelpText("The X coordinate of the area light")]
        float AreaLightX = 0.0f;

        [DisplayName("Position Y")]
        [MinValue(-100.0f)]
        [MaxValue(100.0f)]
        [StepSize(0.01f)]
        [HelpText("The Y coordinate of the area light")]
        float AreaLightY = 5.0f;

        [DisplayName("Position Z")]
        [MinValue(-100.0f)]
        [MaxValue(100.0f)]
        [StepSize(0.01f)]
        [HelpText("The Z coordinate of the area light")]
        float AreaLightZ = 0.0f;

        [DisplayName("Shadow Bias")]
        [MinValue(0.0f)]
        [MaxValue(1.0f)]
        [StepSize(0.001f)]
        float AreaLightShadowBias = 0.001f;

        [HelpText("Bakes the direct contribution from the area light into the light map")]
        bool BakeDirectAreaLight = false;

        bool EnableAreaLightShadows = true;
    }

    [ExpandGroup(false)]
    public class CameraControls
    {
        [HelpText("Specifies how exposure should be controled")]
        ExposureModes ExposureMode = ExposureModes.Manual_SBS;

        [MinValue(-32.0f)]
        [MaxValue(32.0f)]
        [StepSize(0.01f)]
        [HelpText("Manual exposure value when auto-exposure is disabled")]
        float ManualExposure = -16.0f;

        [DisplayName("Aperture")]
        [UseAsShaderConstant(false)]
        FStops ApertureSize = FStops.FStop16Point0;

        [DisplayName("ISO Rating")]
        [UseAsShaderConstant(false)]
        ISORatings ISORating = ISORatings.ISO100;

        [DisplayName("Shutter Speed")]
        [UseAsShaderConstant(false)]
        ShutterSpeeds ShutterSpeed = ShutterSpeeds.ShutterSpeed1Over125;

        [DisplayName("Film Size(mm)")]
        [MinValue(1.0f)]
        [MaxValue(100.0f)]
        [StepSize(0.1f)]
        [ConversionScale(0.001f)]
        float FilmSize = 35.0f;

        [DisplayName("Focal Length(mm)")]
        [MinValue(1.0f)]
        [MaxValue(200.0f)]
        [StepSize(0.1f)]
        [ConversionScale(0.001f)]
        float FocalLength = 35.0f;

        [MinValue(1.0f)]
        [MaxValue(100.0f)]
        [StepSize(0.1f)]
        float FocusDistance = 10.0f;

        [DisplayName("Num Aperture Blades")]
        [MinValue(5)]
        [MaxValue(9)]
        int NumBlades = 5;

        [DisplayName("Enable DOF")]
        [UseAsShaderConstant(false)]
        bool EnableDOF = false;

        [DisplayName("Auto-Exposure Key Value")]
        [MinValue(0.0f)]
        [MaxValue(0.5f)]
        [StepSize(0.01f)]
        [HelpText("Parameter that biases the result of the auto-exposure pass")]
        float KeyValue = 0.115f;

        [DisplayName("Adaptation Rate")]
        [MinValue(0.0f)]
        [MaxValue(4.0f)]
        [StepSize(0.01f)]
        [HelpText("Controls how quickly auto-exposure adapts to changes in scene brightness")]
        float AdaptationRate = 0.5f;

        // Virtuals
        [VirtualSetting("ApertureFNumber_()")]
        [Visible(false)]
        float ApertureFNumber;

        [VirtualSetting("ApertureWidth_()")]
        [Visible(false)]
        float ApertureWidth;

        [VirtualSetting("ShutterSpeedValue_()")]
        [Visible(false)]
        float ShutterSpeedValue;

        [VirtualSetting("ISO_()")]
        [Visible(false)]
        float ISO;

        [VirtualSetting("BokehPolygonAmount_()")]
        [Visible(false)]
        float BokehPolygonAmount;
    }

    [ExpandGroup(false)]
    public class ToneMapping
    {
        [DisplayName("Tone Mapping Operator")]
        ToneMappingModes ToneMappingMode = ToneMappingModes.ACES;

        [MinValue(0.01f)]
        [StepSize(0.01f)]
        [DisplayName("White Point (Hejl2015)")]
        float WhitePoint_Hejl = 1.0f;

        [MinValue(0.01f)]
        [StepSize(0.01f)]
        float ShoulderStrength = 4.0f;

        [MinValue(0.01f)]
        [StepSize(0.01f)]
        float LinearStrength = 5.0f;

        [MinValue(0.01f)]
        [StepSize(0.01f)]
        float LinearAngle = 0.12f;

        [MinValue(0.01f)]
        [StepSize(0.01f)]
        float ToeStrength = 13.0f;

        [MinValue(0.01f)]
        [StepSize(0.01f)]
        [DisplayName("White Point (Hable)")]
        float WhitePoint_Hable = 6.0f;
    }

    [ExpandGroup(false)]
    public class AntiAliasing
    {
        MSAAModes MSAAMode = MSAAModes.MSAA4x;

        FilterTypes FilterType = FilterTypes.Smoothstep;

        [MinValue(0.0f)]
        [MaxValue(6.0f)]
        [StepSize(0.01f)]
        float FilterSize = 2.0f;

        [MinValue(0.01f)]
        [MaxValue(1.0f)]
        [StepSize(0.01f)]
        float GaussianSigma = 0.5f;

        [UseAsShaderConstant(false)]
        bool EnableTemporalAA = true;

        [UseAsShaderConstant(false)]
        JitterModes JitterMode = JitterModes.Hammersley4x;

        [MinValue(0.0f)]
        [UseAsShaderConstant(false)]
        float JitterScale = 1.0f;
    }

    const int MaxSGCount = 12;
    const int MaxBasisCount = MaxSGCount;

    [ExpandGroup(false)]
    [DisplayName("SG Settings")]
    public class SGSettings
    {
        [DisplayName("SG Diffuse Mode")]
        SGDiffuseModes SGDiffuseMode = SGDiffuseModes.Fitted;

        [DisplayName("Use ASG Warp")]
        SGSpecularModes SGSpecularMode = SGSpecularModes.ASGWarp;
    }

    [ExpandGroup(false)]
    [DisplayName("SH Settings")]
    public class SHSettings
    {
        [DisplayName("L1 SH Diffuse Mode")]
        SH4DiffuseModes SH4DiffuseMode = SH4DiffuseModes.Convolution;

        [DisplayName("SH Specular Mode")]
        SHSpecularModes SHSpecularMode = SHSpecularModes.Convolution;
    }

    [ExpandGroup(false)]
    public class Baking
    {
        [DisplayName("Light Map Resolution")]
        [HelpText("The texture resolution of the light map")]
        [MinValue(64)]
        [MaxValue(4096)]
        int LightMapResolution = 256;

        [HelpText("The square root of the number of sample rays to use for baking GI")]
        [MinValue(1)]
        [MaxValue(100)]
        [UseAsShaderConstant(false)]
        [DisplayName("Sqrt Num Samples")]
        int NumBakeSamples = 25;

        [UseAsShaderConstant(false)]
        [DisplayName("Sample Mode")]
        SampleModes BakeSampleMode = SampleModes.CMJ;

        [HelpText("Maximum path length (bounces + 2) to use for baking GI (set to -1 for infinite)")]
        [UseAsShaderConstant(false)]
        [MinValue(-1)]
        int MaxBakePathLength = -1;

        [HelpText("Path length at which Russian roulette kicks in (-1 to disable)")]
        [UseAsShaderConstant(false)]
        [MinValue(-1)]
        [DisplayName("Russian Roullette Depth")]
        int BakeRussianRouletteDepth = 4;

        [HelpText("Maximum probability for continuing when Russian roulette is used")]
        [UseAsShaderConstant(false)]
        [MinValue(0.0f)]
        [MaxValue(1.0f)]
        [StepSize(0.01f)]
        [DisplayName("Russian Roullette Probability")]
        float BakeRussianRouletteProbability = 0.5f;

        [HelpText("The current encoding/basis used for baking light map sample points")]
        BakeModes BakeMode = BakeModes.SG5;

        [HelpText("Controls how path tracer radiance samples are converted into a set of per-texel SG lobes")]
        SolveModes SolveMode = SolveModes.RunningAverageNN;

        [HelpText("If true, the sample points are baked in a world-space orientation instead of tangent space (SH and SG bake modes only)")]
        bool WorldSpaceBake = false;
    }

    [ExpandGroup(false)]
    public class Scene
    {
        [UseAsShaderConstant(false)]
        Scenes CurrentScene = Scenes.Box;

        [DisplayName("Enable Diffuse")]
        [HelpText("Enables diffuse lighting")]
        bool EnableDiffuse = true;

        [DisplayName("Enable Specular")]
        [HelpText("Enables specular lighting")]
        bool EnableSpecular = true;

        [DisplayName("Enable Direct Lighting")]
        [HelpText("Enables direct lighting")]
        bool EnableDirectLighting = true;

        [DisplayName("Enable Indirect Lighting")]
        [HelpText("Enables indirect lighting")]
        bool EnableIndirectLighting = true;

        [DisplayName("Enable Indirect Diffuse")]
        [HelpText("Enables indirect diffuse lighting")]
        bool EnableIndirectDiffuse = true;

        [DisplayName("Enable Indirect Specular")]
        [HelpText("Enables indirect specular lighting")]
        bool EnableIndirectSpecular = true;

        [DisplayName("Enable Albedo Maps")]
        [HelpText("Enables albedo maps")]
        bool EnableAlbedoMaps = true;

        [DisplayName("Enable Normal Maps")]
        [HelpText("Enables normal maps")]
        bool EnableNormalMaps = true;

        [DisplayName("Normal Map Intensity")]
        [MinValue(0.0f)]
        [MaxValue(1.0f)]
        [StepSize(0.01f)]
        [HelpText("Intensity of the normal map")]
        float NormalMapIntensity = 0.5f;

        [DisplayName("Diffuse Albedo Scale")]
        [MinValue(0.0f)]
        [StepSize(0.01f)]
        [HelpText("Global scale applied to all material diffuse albedo values")]
        float DiffuseAlbedoScale = 0.5f;

        [DisplayName("Specular Roughness Scale")]
        [MinValue(0.01f)]
        [StepSize(0.01f)]
        [HelpText("Global scale applied to all material roughness values")]
        float RoughnessScale = 2.0f;

        [MinValue(-1.0f)]
        [MaxValue(1.0f)]
        float MetallicOffset = 0.0f;
    }

    [ExpandGroup(false)]
    public class GroundTruth
    {
        [DisplayName("Show Ground Truth")]
        [HelpText("If enabled, shows a ground truth image rendered on the CPU")]
        [UseAsShaderConstant(false)]
        bool ShowGroundTruth = false;

        [HelpText("The square root of the number of per-pixel sample rays to use for ground truth rendering")]
        [UseAsShaderConstant(false)]
        [MinValue(1)]
        [MaxValue(100)]
        [DisplayName("Sqrt Num Samples")]
        int NumRenderSamples = 4;

        [UseAsShaderConstant(false)]
        [DisplayName("Sample Mode")]
        SampleModes RenderSampleMode = SampleModes.CMJ;

        [HelpText("Maximum path length (bounces) to use for ground truth rendering (set to -1 for infinite)")]
        [UseAsShaderConstant(false)]
        [MinValue(-1)]
        [DisplayName("Max Path Length")]
        int MaxRenderPathLength = -1;

        [HelpText("Path length at which Russian roulette kicks in (-1 to disable)")]
        [UseAsShaderConstant(false)]
        [MinValue(-1)]
        [DisplayName("Russian Roullette Depth")]
        int RenderRussianRouletteDepth = 4;

        [HelpText("Maximum probability for continuing when Russian roulette is used")]
        [UseAsShaderConstant(false)]
        [MinValue(0.0f)]
        [MaxValue(1.0f)]
        [StepSize(0.01f)]
        [DisplayName("Russian Roullette Probability")]
        float RenderRussianRouletteProbability = 0.5f;

        [DisplayName("Enable Bounce Specular")]
        [HelpText("Enables specular calculations after the first hit")]
        [UseAsShaderConstant(false)]
        bool EnableRenderBounceSpecular = false;
    }

    [ExpandGroup(false)]
    public class PostProcessing
    {
        [DisplayName("Bloom Exposure Offset")]
        [MinValue(-10.0f)]
        [MaxValue(0.0f)]
        [StepSize(0.01f)]
        [HelpText("Exposure offset applied to generate the input of the bloom pass")]
        float BloomExposure = -4.0f;

        [DisplayName("Bloom Magnitude")]
        [MinValue(0.0f)]
        [MaxValue(2.0f)]
        [StepSize(0.01f)]
        [HelpText("Scale factor applied to the bloom results when combined with tone-mapped result")]
        float BloomMagnitude = 1.0f;

        [DisplayName("Bloom Blur Sigma")]
        [MinValue(0.5f)]
        [MaxValue(2.5f)]
        [StepSize(0.01f)]
        [HelpText("Sigma parameter of the Gaussian filter used in the bloom pass")]
        float BloomBlurSigma = 2.5f;
    }

    [ExpandGroup(false)]
    public class Debug
    {
        [UseAsShaderConstant(false)]
        bool EnableLuminancePicker = false;

        [UseAsShaderConstant(false)]
        bool ShowBakeDataVisualizer = false;

        bool ViewIndirectDiffuse = false;
        bool ViewIndirectSpecular = false;

        [MinValue(0.0f)]
        [MaxValue(1.0f)]
        float RoughnessOverride = 0.0f;

        [DisplayName("Save Light Settings")]
        [HelpText("Saves the lighting settings to a file")]
        Button SaveLightSettings;

        [DisplayName("Load Light Settings")]
        [HelpText("Loads the lighting settings from a file")]
        Button LoadLightSettings;

        [DisplayName("Save EXR Screenshot")]
        [HelpText("Captures the current screen image in EXR format")]
        Button SaveEXRScreenshot;

        [UseAsShaderConstant(false)]
        bool ShowSunIntensity = false;
    }
}