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

#include "resource.h"

using namespace SampleFramework11;
using std::wstring;

static const float NearClip = 0.01f;
static const float FarClip = 100.0f;

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

Baker::Baker()
{
    deviceManager.Initialize(GetDesktopWindow());
    deviceManager.SetMinFeatureLevel(D3D_FEATURE_LEVEL_11_0);
}

void Baker::MeshbakerInitialize(const Model* sceneModel, Lights &&lights)
{

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

void Baker::Init(const Scene *s)
{
    auto device = deviceManager.Device();

    sceneModel.CreateFromScene(device, s, false);
    BakeInputData bakeInput;
    bakeInput.SceneModel = &sceneModel;
    bakeInput.Device = device;

    InitLights(s, bakeInput.lights);
    meshBaker.Initialize(bakeInput);

    PrintString("baker cube map need set");
}

void Baker::Bake(uint32 bakeMeshIdx)
{
    meshBaker.SetBakeMesh(bakeMeshIdx);
    meshBaker.StartBake();
    while (meshBaker.Process() < 1.f) ;
    meshBaker.EndBake();  //process set to 1.0, but bake thread still have some work not finish, need to wait it end
}

void Baker::ShutDown()
{
    ShutdownShaders();
}

const FixedArray<Float4>& Baker::GetBakeResult(uint64 basicIdx) const
{
    return meshBaker.bakeResults[basicIdx];
}