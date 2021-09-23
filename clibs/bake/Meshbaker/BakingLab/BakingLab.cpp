//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include <PCH.h>

#include <InterfacePointers.h>
#include <Window.h>
#include <Graphics/DeviceManager.h>
#include <Input.h>
#include <Utility.h>
#include <Graphics/ShaderCompilation.h>
#include <Graphics/Profiler.h>
#include <Graphics/Sampling.h>
#include <Graphics/BRDF.h>
#include <FileIO.h>

#include "BakingLab.h"
#include "MeshBaker.h"
#include "SG.h"
#include "TwHelper.h"

#include "resource.h"

using namespace SampleFramework11;
using std::wstring;

const uint32 WindowWidth = 1280;
const uint32 WindowHeight = 720;
const float WindowWidthF = static_cast<float>(WindowWidth);
const float WindowHeightF = static_cast<float>(WindowHeight);

static const float NearClip = 0.01f;
static const float FarClip = 100.0f;

#define UseCachedLightmap_ (1)
#define WriteCachedLightmap_ (Release_ && UseCachedLightmap_)

// Model filenames
static const std::wstring ScenePaths[] =
{
    ContentDir() + L"Models\\Box\\Box_Lightmap.fbx",
    ContentDir() + L"Models\\WhiteRoom\\WhiteRoom.fbx",
    ContentDir() + L"Models\\Sponza\\Sponza_Lightmap.fbx",
};

static const Float3 SceneCameraPositions[] = { Float3(0.0f, 2.5f, -15.0f), Float3(0.0f, 2.5f, 0.0f), Float3(-5.12373829f, 13.8305235f, -0.463505715f) };
static const Float2 SceneCameraRotations[] = { Float2(0.0f, 0.0f), Float2(0.0f, Pi), Float2(0.414238036f, 1.39585948f) };
static const float SceneAlbedoScales[] = { 0.5f, 0.5f, 1.0f };

StaticAssert_(ArraySize_(ScenePaths) >= uint64(Scenes::NumValues));
StaticAssert_(ArraySize_(SceneCameraPositions) >= uint64(Scenes::NumValues));
StaticAssert_(ArraySize_(SceneCameraRotations) >= uint64(Scenes::NumValues));
StaticAssert_(ArraySize_(SceneAlbedoScales) >= uint64(Scenes::NumValues));

static Setting* LightSettings[] =
{
    &AppSettings::EnableSun,
    &AppSettings::BakeDirectSunLight,
    &AppSettings::SunTintColor,
    &AppSettings::SunIntensityScale,
    &AppSettings::SunSize,
    &AppSettings::NormalizeSunIntensity,
    &AppSettings::SunAzimuth,
    &AppSettings::SunElevation,
    &AppSettings::SkyMode,
    &AppSettings::SkyColor,
    &AppSettings::Turbidity,
    &AppSettings::GroundAlbedo,
    &AppSettings::EnableAreaLight,
    &AppSettings::EnableAreaLightShadows,
    &AppSettings::AreaLightColor,
    &AppSettings::AreaLightIlluminance,
    &AppSettings::AreaLightLuminousPower,
    &AppSettings::AreaLightEV100,
    &AppSettings::AreaLightIlluminanceDistance,
    &AppSettings::AreaLightSize,
    &AppSettings::AreaLightX,
    &AppSettings::AreaLightY,
    &AppSettings::AreaLightZ,
    &AppSettings::AreaLightShadowBias,
    &AppSettings::BakeDirectAreaLight,
    &AppSettings::AreaLightUnits,
};

static const uint64 NumLightSettings = ArraySize_(LightSettings);

struct SettingInfo
{
    std::string Name;
    uint64 DataSize = 0;

    template<typename TSerializer> void Serialize(TSerializer& serializer)
    {
        SerializeItem(serializer, Name);
        SerializeItem(serializer, DataSize);
    }
};

// Save lighting settings to a file
static void LoadLightSettings(HWND parentWindow)
{
    wchar currDirectory[MAX_PATH] = { 0 };
    GetCurrentDirectory(ArraySize_(currDirectory), currDirectory);

    wchar filePath[MAX_PATH] = { 0 };

    OPENFILENAME ofn;
    ZeroMemory(&ofn , sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = parentWindow;
    ofn.lpstrFile = filePath;
    ofn.nMaxFile = ArraySize_(filePath);
    ofn.lpstrFilter = L"All Files (*.*)\0*.*\0Light Settings (*.lts)\0*.lts\0";
    ofn.nFilterIndex = 2;
    ofn.lpstrFileTitle = nullptr;
    ofn.nMaxFileTitle = 0;
    ofn.lpstrInitialDir = nullptr;
    ofn.lpstrTitle = L"Open Light Settings File..";
    ofn.lpstrDefExt = L"lts";
    ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;
    bool succeeded = false; //GetOpenFileName(&ofn) != 0;
    SetCurrentDirectory(currDirectory);

    if(succeeded)
    {
        try
        {
            FileReadSerializer serializer(filePath);

            std::vector<SettingInfo> settingInfo;
            SerializeItem(serializer, settingInfo);

            uint8 dummyBuffer[1024] = { 0 };
            for(uint64 i = 0; i < settingInfo.size(); ++i)
            {
                const SettingInfo& info = settingInfo[i];
                Setting* setting = Settings.FindSetting(info.Name);
                if(setting == nullptr || setting->SerializedValueSize() != info.DataSize)
                {
                    // Skip the data for this setting, it's out-of-date
                    Assert_(info.DataSize <= sizeof(dummyBuffer));
                    if(info.DataSize > 0)
                        serializer.SerializeData(info.DataSize, dummyBuffer);
                    continue;
                }

                setting->SerializeValue(serializer);
            }
        }
        catch(Exception e)
        {
            std::wstring errorString = L"Error occured while loading light settings file: " + e.GetMessage();
            MessageBox(parentWindow, errorString.c_str(), L"Error", MB_OK | MB_ICONERROR);
        }
    }

    SetCurrentDirectory(currDirectory);
}

// Save lighting settings to a file
static void SaveLightSettings(HWND parentWindow)
{
    wchar currDirectory[MAX_PATH] = { 0 };
    GetCurrentDirectory(ArraySize_(currDirectory), currDirectory);

    wchar filePath[MAX_PATH] = { 0 };

    OPENFILENAME ofn;
    ZeroMemory(&ofn , sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = parentWindow;
    ofn.lpstrFile = filePath;
    ofn.nMaxFile = ArraySize_(filePath);
    ofn.lpstrFilter = L"All Files (*.*)\0*.*\0Light Settings (*.lts)\0*.lts\0";
    ofn.nFilterIndex = 2;
    ofn.lpstrFileTitle = nullptr;
    ofn.nMaxFileTitle = 0;
    ofn.lpstrInitialDir = nullptr;
    ofn.lpstrTitle = L"Save Light Settings File As..";
    ofn.lpstrDefExt = L"lts";
    ofn.Flags = OFN_OVERWRITEPROMPT;
    bool succeeded = false; //GetSaveFileName(&ofn) != 0;
    SetCurrentDirectory(currDirectory);

    if(succeeded)
    {
        try
        {
            std::vector<SettingInfo> settingInfo;
            settingInfo.resize(NumLightSettings);
            for(uint64 i = 0; i < NumLightSettings; ++i)
            {
                // Serialize some metadata so that we can skip out of date settings on load
                settingInfo[i].Name = LightSettings[i]->Name();
                settingInfo[i].DataSize = LightSettings[i]->SerializedValueSize();
                Assert_(settingInfo[i].DataSize > 0);
            }

            FileWriteSerializer serializer(filePath);
            SerializeItem(serializer, settingInfo);

            for(uint64 i = 0; i < NumLightSettings; ++i)
                LightSettings[i]->SerializeValue(serializer);
        }
        catch(Exception e)
        {
            std::wstring errorString = L"Error occured while saving light settings file:\n" + e.GetMessage();
            MessageBox(parentWindow, errorString.c_str(), L"Error", MB_OK | MB_ICONERROR);
        }
    }

    SetCurrentDirectory(currDirectory);
}

// Save a skydome texture as a DDS file
static void SaveEXRScreenshot(HWND parentWindow, ID3D11ShaderResourceView* screenSRV)
{
    // Read the texture data, and apply the inverse exposure scale
    ID3D11DevicePtr device;
    screenSRV->GetDevice(&device);

    TextureData<Float4> textureData;
    GetTextureData(device, screenSRV, textureData);

    const uint64 numTexels = textureData.Texels.size();
    for(uint64 i = 0; i < numTexels; ++i)
    {
        textureData.Texels[i] *= 1.0f / FP16Scale;
        textureData.Texels[i] = Float4::Clamp(textureData.Texels[i], 0.0f, FP16Max);
    }

    wchar currDirectory[MAX_PATH] = { 0 };
    GetCurrentDirectory(ArraySize_(currDirectory), currDirectory);

    wchar filePath[MAX_PATH] = { 0 };

    OPENFILENAME ofn;
    ZeroMemory(&ofn , sizeof(ofn));
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = parentWindow;
    ofn.lpstrFile = filePath;
    ofn.nMaxFile = ArraySize_(filePath);
    ofn.lpstrFilter = L"All Files (*.*)\0*.*\0EXR Files (*.exr)\0*.exr\0";
    ofn.nFilterIndex = 2;
    ofn.lpstrFileTitle = nullptr;
    ofn.nMaxFileTitle = 0;
    ofn.lpstrInitialDir = nullptr;
    ofn.lpstrTitle = L"Save Screenshot As..";
    ofn.lpstrDefExt = L"exr";
    ofn.Flags = OFN_OVERWRITEPROMPT;
    bool succeeded = false;//GetSaveFileName(&ofn) != 0;
    SetCurrentDirectory(currDirectory);

    if(succeeded)
    {
        try
        {
            SaveTextureAsEXR(textureData, filePath);
        }
        catch(Exception e)
        {
            std::wstring errorString = L"Error occured while saving screenshot as an EXR file:\n" + e.GetMessage();
            MessageBox(parentWindow, errorString.c_str(), L"Error", MB_OK | MB_ICONERROR);
        }
    }
}

// Bakes lookup textures for computing environment specular from radiance encoded as spherical harmonics.
static void GenerateSHSpecularLookupTextures(ID3D11Device* device)
{
    static const uint32 ViewResolution = 32;
    static const uint32 RoughnessResolution = 32;
    static const uint32 FresnelResolution = 32;
    #if Debug_
        static const uint64 SqrtNumSamples = 10;
    #else
        static const uint64 SqrtNumSamples = 25;
    #endif
    static const uint64 NumSamples = SqrtNumSamples * SqrtNumSamples;
    std::vector<Half4> texData0(ViewResolution * RoughnessResolution * FresnelResolution);
    std::vector<Half2> texData1(ViewResolution * RoughnessResolution * FresnelResolution);

    int32 pattern = 0;
    const Float3 n = Float3(0.0f, 0.0f, 1.0f);

    // Integrate the specular BRDF for a fixed value of Phi (camera lined up with the X-axis)
    // for a set of viewing angles and roughness values
    for(uint32 fIdx = 0; fIdx < FresnelResolution; ++fIdx)
    {
        const float specAlbedo = (fIdx + 0.5f) / FresnelResolution;
        for(uint32 mIdx = 0; mIdx < RoughnessResolution; ++mIdx)
        {
            const float SqrtRoughness = (mIdx + 0.5f) / RoughnessResolution;
            const float Roughness = SqrtRoughness * SqrtRoughness;
            for(uint32 vIdx = 0; vIdx < ViewResolution; ++vIdx)
            {
                Float3 v = 0.0f;
                v.z = (vIdx + 0.5f) / ViewResolution;
                v.x = std::sqrt(1.0f - Saturate(v.z * v.z));

                SH9 finalSH;
                SH9 accumulatedSH;

                uint32 accumulatedSamples = 0;
                for(uint64 sampleIdx = 0; sampleIdx < NumSamples; ++sampleIdx)
                {
                    ++accumulatedSamples;

                    Float2 sampleCoord = SampleCMJ2D(int32(sampleIdx), int32(SqrtNumSamples), int32(SqrtNumSamples), 0);
                    Float3 l = SampleDirectionGGX(v, n, Roughness, Float3x3(), sampleCoord.x, sampleCoord.y);
                    Float3 h = Float3::Normalize(v + l);
                    float nDotL = Saturate(l.z);

                    if(nDotL > 0.0f)
                    {
                        float pdf = GGX_PDF(n, h, v, Roughness);
                        float brdf = GGX_Specular(Roughness, n, h, v, l) * Fresnel(specAlbedo, h, l).x;
                        accumulatedSH += ProjectOntoSH9(l) * brdf * nDotL / pdf;
                    }

                    if(accumulatedSamples >= 1000)
                    {
                        finalSH += accumulatedSH / float(NumSamples);
                        accumulatedSH = SH9();
                        accumulatedSamples = 0;
                    }
                }

                if(accumulatedSamples > 0)
                    finalSH += accumulatedSH / float(NumSamples);

                const uint64 idx = (fIdx * ViewResolution * RoughnessResolution) + (mIdx * ViewResolution) + vIdx;
                texData0[idx] = Half4(finalSH[0], finalSH[2], finalSH[3], finalSH[6]);
                texData1[idx] = Half2(finalSH[7], finalSH[8]);
            }
        }
    }

    // Make 2 3D textures
    D3D11_TEXTURE3D_DESC desc;
    desc.Width = ViewResolution;
    desc.Height = RoughnessResolution;
    desc.Depth = FresnelResolution;
    desc.Format = DXGI_FORMAT_R16G16B16A16_FLOAT;
    desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    desc.Usage = D3D11_USAGE_IMMUTABLE;
    desc.MipLevels = 1;
    desc.CPUAccessFlags = 0;
    desc.MiscFlags = 0;

    D3D11_SUBRESOURCE_DATA srData;
    srData.pSysMem = texData0.data();
    srData.SysMemPitch = sizeof(Half4) * desc.Width;
    srData.SysMemSlicePitch = sizeof(Half4) * desc.Width * desc.Height;

    ID3D11Texture3DPtr texture0;
    DXCall(device->CreateTexture3D(&desc, &srData, &texture0));

    desc.Format = DXGI_FORMAT_R16G16_FLOAT;
    srData.pSysMem = texData1.data();
    srData.SysMemPitch = sizeof(Half2) * desc.Width;
    srData.SysMemSlicePitch = sizeof(Half2) * desc.Width * desc.Height;

    ID3D11Texture3DPtr texture1;
    DXCall(device->CreateTexture3D(&desc, &srData, &texture1));

    SaveTextureAsDDS(texture0, (ContentDir() + L"Textures\\SHSpecularA.dds").c_str());
    SaveTextureAsDDS(texture1, (ContentDir() + L"Textures\\SHSpecularB.dds").c_str());
}

// Bakes a lookup texture containing a scale bias that can be used for sampling a pre-filtered environment map
// with a split-sum approximation
static void GenerateEnvSpecularLookupTexture(ID3D11Device* device)
{
    std::string csvOutput = "SqrtRoughness,NDotV,A,B,Delta\n";

    const uint32 NumVSamples = 64;
    const uint32 NumRSamples = 64;
    const uint32 SqrtNumSamples = 32;
    const uint32 NumSamples = SqrtNumSamples * SqrtNumSamples;

    FixedArray<Half2> texels;
    texels.Init(NumVSamples * NumRSamples);

    uint32 texelIdx = 0;

    const Float3 n = Float3(0.0f, 0.0f, 1.0f);

    for(uint32 rIdx = 0; rIdx < NumRSamples; ++rIdx)
    {
        const float sqrtRoughness = (rIdx + 0.5f) / NumRSamples;
        const float roughness = Max(sqrtRoughness * sqrtRoughness, 0.001f);

        for(uint32 vIdx = 0; vIdx < NumVSamples; ++vIdx)
        {
            const float nDotV = (vIdx + 0.5f) / NumVSamples;

            Float3 v = 0.0f;
            v.z = nDotV;
            v.x = std::sqrt(1.0f - Saturate(v.z * v.z));

            float A = 0.0f;
            float B = 0.0f;

            for(uint32 sIdx = 0; sIdx < NumSamples; ++sIdx)
            {

                const Float2 u1u2 = SampleCMJ2D(sIdx, SqrtNumSamples, SqrtNumSamples, 0);

                const Float3 h = SampleGGXMicrofacet(roughness, u1u2.x, u1u2.y);
                const float hDotV = Float3::Dot(h, v);
                const Float3 l = 2.0f * hDotV * h - v;

                const float nDotL = l.z;

                if(nDotL > 0.0f)
                {
                    const float pdf = GGX_PDF(n, h, v, roughness);
                    const float sampleWeight = GGX_Specular(roughness, n, h, v, l) * nDotL / pdf;

                    const float fc = std::pow(1 - Saturate(hDotV), 5.0f);

                    A += (1.0f - fc) * sampleWeight;
                    B += fc * sampleWeight;
                }
            }

            A /= NumSamples;
            B /= NumSamples;
            texels[texelIdx] = Half2(A, B);

            ++texelIdx;

            csvOutput += MakeAnsiString("%f,%f,%f,%f,%f\n", sqrtRoughness, nDotV, A, B, A + B);
        }
    }

    D3D11_TEXTURE2D_DESC desc = { };
    desc.Width = NumRSamples;
    desc.Height = NumVSamples;
    desc.ArraySize = 1;
    desc.Format = DXGI_FORMAT_R16G16_FLOAT;
    desc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
    desc.Usage = D3D11_USAGE_IMMUTABLE;
    desc.MipLevels = 1;
    desc.CPUAccessFlags = 0;
    desc.MiscFlags = 0;
    desc.SampleDesc.Count = 1;

    D3D11_SUBRESOURCE_DATA srData = { };
    srData.pSysMem = texels.Data();
    srData.SysMemPitch = sizeof(Half2) * desc.Width;

    ID3D11Texture2DPtr texture;
    DXCall(device->CreateTexture2D(&desc, &srData, &texture));

    SaveTextureAsDDS(texture, (ContentDir() + L"Textures\\EnvSpecularLookup.dds").c_str());

    WriteStringAsFile(L"EnvBRDF.csv", csvOutput);
}

BakingLab::BakingLab()
{
    deviceManager.Initialize(nullptr);
    deviceManager.SetMinFeatureLevel(D3D_FEATURE_LEVEL_11_0);
}

void BakingLab::MeshbakerInitialize(const Model* sceneModel, Lights &&lights)
{
    auto device = deviceManager.Device();
    for(uint64 i = 0; i < AppSettings::NumCubeMaps; ++i)
        envMaps[i] = LoadTexture(device, AppSettings::CubeMapPaths(i).c_str());

    BakeInputData bakeInput;
    bakeInput.SceneModel = sceneModel;
    bakeInput.Device = device;
    bakeInput.lights = lights;
    for(uint64 i = 0; i < AppSettings::NumCubeMaps; ++i)
        bakeInput.EnvMaps[i] = envMaps[i];
    meshBaker.Initialize(bakeInput);
}

void BakingLab::Update(const Timer& timer)
{
    // meshbakerStatus = meshBaker.Update(unJitteredCamera, colorTargetMSAA.Width, colorTargetMSAA.Height,
    //                                           context, &sceneModels[AppSettings::CurrentScene]);
}

static void GenerateGaussianIrradianceTable(float sharpness, const wchar* filePath)
{
    std::string output;

    const uint64 NumPoints = 50;
    for(uint64 pointIdx = 0; pointIdx < NumPoints; ++pointIdx)
    {
        float theta = Pi * pointIdx / (NumPoints - 1.0f);
        Float3 localSGDir = Float3(std::sin(-theta), 0.0f, std::cos(-theta));

        const uint64 SqrtNumSamples = 64;
        const uint64 NumSamples = SqrtNumSamples * SqrtNumSamples;
        float sum = 0.0f;
        for(uint64 sampleIdx = 0; sampleIdx < NumSamples; ++sampleIdx)
        {
            Float2 samplePoint = SampleCMJ2D(int32(sampleIdx), int32(SqrtNumSamples), int32(SqrtNumSamples), int32(pointIdx));
            Float3 sampleDir = SampleCosineHemisphere(samplePoint.x, samplePoint.y);
            sum += std::exp(sharpness * (Float3::Dot(sampleDir, localSGDir) - 1.0f));
        }

        sum *= (Pi / NumSamples);

        output += MakeAnsiString("%f,%f\n", theta, sum);
    }

    WriteStringAsFile(filePath, output);
}

static void GenerateSGInnerProductIrradianceTable(float sharpness, const wchar* filePath)
{
    std::string output;

    SG sgLight;
    sgLight.Amplitude = 1.0f;
    sgLight.Axis = Float3(0.0f, 0.0f, 1.0f);
    sgLight.Sharpness = sharpness;

    const uint64 NumPoints = 50;
    for(uint64 pointIdx = 0; pointIdx < NumPoints; ++pointIdx)
    {
        float theta = Pi * pointIdx / (NumPoints - 1.0f);
        Float3 normal = Float3(std::sin(theta), 0.0f, std::cos(theta));

        SG cosineLobe = CosineLobeSG(normal);
        float irradiance = Max(SGInnerProduct(sgLight, cosineLobe).x, 0.0f);

        output += MakeAnsiString("%f,%f\n", theta, irradiance);
    }

    WriteStringAsFile(filePath, output);
}

static void GenerateSGFittedIrradianceTable(float sharpness, const wchar* filePath)
{
    std::string output;

    SG sgLight;
    sgLight.Amplitude = 1.0f;
    sgLight.Axis = Float3(0.0f, 0.0f, 1.0f);
    sgLight.Sharpness = sharpness;

    const uint64 NumPoints = 50;
    for(uint64 pointIdx = 0; pointIdx < NumPoints; ++pointIdx)
    {
        float theta = Pi * pointIdx / (NumPoints - 1.0f);
        Float3 normal = Float3(std::sin(theta), 0.0f, std::cos(theta));

        float irradiance = SGIrradianceFitted(sgLight, normal).x;

        output += MakeAnsiString("%f,%f\n", theta, irradiance);
    }

    WriteStringAsFile(filePath, output);
}

static void GenerateSHGGXProjectionTable()
{
    std::string output = "Roughness,C2,C6\n";

    const Float3 n = Float3(0.0f, 0.0f, 1.0f);
    const Float3 v = Float3(0.0f, 0.0f, 1.0f);

    SH9 proj0;

    const uint32 NumRSamples = 64;
    for(uint32 rIdx = 0; rIdx < NumRSamples; ++rIdx)
    {
        const float sqrtRoughness = (rIdx + 0.5f) / NumRSamples;
        const float roughness = sqrtRoughness * sqrtRoughness;

        SH9 proj;
        float weightSum = 0.00001f;

        const uint32 SqrtNumSamples = 32;
        const uint32 NumSamples = SqrtNumSamples * SqrtNumSamples;
        for(uint32 sIdx = 0; sIdx < NumSamples; ++sIdx)
        {
            const Float2 randFloats = SampleCMJ2D(sIdx, SqrtNumSamples, SqrtNumSamples, 0);

            Float3 h = SampleGGXMicrofacet(roughness, randFloats.x, randFloats.y);
            float hDotV = h.z;
            Float3 l = Float3::Normalize(2.0f * hDotV * h - v);

            float nDotL = l.z;
            if(nDotL > 0)
            {
                proj += ProjectOntoSH9(l) * nDotL;
                weightSum += nDotL;
            }
        }

        proj /= weightSum;

        if(rIdx == 0)
            proj0 = proj;

        proj /= proj0;

        output += MakeAnsiString("%f,%f,%f\n", sqrtRoughness, proj[2], proj[6]);
    }

    WriteStringAsFile(L"SH_GGX_Proj.csv", output);
}

void BakingLab::Init(const Scene *s)
{
    auto device = deviceManager.Device();

    sceneModels.CreateFromScene(device, s, false);
    Lights lights;
    InitLights(s, lights);
    MeshbakerInitialize(&sceneModels[AppSettings::CurrentScene], std::move(lights));
    PrintString("baker cube map need set");
}

float BakingLab::BakeProcess()
{
    timer.Update();
    Settings.Update();

    AppSettings::Update();

    ID3D11DeviceContextPtr context = deviceManager.ImmediateContext();
    meshbakerStatus = meshBaker.Update(unJitteredCamera, 0, 0, //colorTargetMSAA.Width, colorTargetMSAA.Height,
                                        context, &sceneModels[AppSettings::CurrentScene]);
    AppSettings::UpdateCBuffer(deviceManager.ImmediateContext());
    assert(meshbakerStatus.GroundTruth == nullptr);
    return meshbakerStatus.BakeProgress;
}

void BakingLab::Bake(uint32 bakeMeshIdx)
{
    meshBaker.bakeMeshIdx = bakeMeshIdx;
    while (BakeProcess() < 1.f) ;
    meshBaker.WaitBakeThreadEnd();  //process set to 1.0, but bake thread still have some work not finish, need to wait it end
    meshBaker.bakeMeshIdx = UINT32_MAX;
}

void BakingLab::ShutDown()
{
    ShutdownShaders();
}

const FixedArray<Float4>& BakingLab::GetBakeResult(uint64 basicIdx) const
{
    return meshBaker.bakeResults[basicIdx];
}