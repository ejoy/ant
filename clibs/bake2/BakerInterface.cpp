#include "BakerInterface.h"

#include "Meshbaker/BakingLab/BakingLab.h"
#include "Meshbaker/BakingLab/AppSettings.h"

static inline uint32_t _FindDirectionalLight(const Scene *scene){
    for (uint32_t idx=0; idx<scene->lights.size(); ++idx){
        auto l = scene->lights[idx];
        if (l.type == LT_Directional){
            return idx;
        }

        assert(false && "not support other light right now");
    }

    return UINT32_MAX;
}

BakerHandle CreateBaker(const Scene* scene){
    auto bl = new BakingLab();
    AppSettings::BakeMode.SetValue(BakeModes::Diffuse);

    auto lidx = _FindDirectionalLight(scene);
    if (lidx != UINT32_MAX){
        AppSettings::BakeDirectSunLight.SetValue(true);
        const auto& l = scene->lights[lidx];
        if (l.size != 0){
            AppSettings::SunSize.SetValue(l.size);
        }
        AppSettings::SunTintColor.SetValue(Float3(l.color.x, l.color.y, l.color.z));
        AppSettings::SunDirection.SetValue(Float3(l.dir.x, l.dir.y, l.dir.z));
    }

    AppSettings::BakeDirectAreaLight.SetValue(false);
    AppSettings::SkyMode.SetValue(SkyModes::Simple);

    bl->Init();
    return bl;
}

void Bake(BakerHandle handle, BakeResult *result){
    auto bl = (BakingLab*)handle;


    const auto &meshes = bl->GetModel(0).Meshes();
    for (uint32_t bakeMeshIdx=0; bakeMeshIdx<meshes.size(); ++bakeMeshIdx){
        bl->Bake(bakeMeshIdx);
    }
}

void DestroyBaker(BakerHandle handle){
    auto bl = (BakingLab*)handle;
    bl->ShutDown();

    delete bl;
}

#include "Meshbaker/SampleFramework11/v1.02/Graphics/Model.h"
void Model::CreateFromScene(ID3D11Device *device, const Scene *scene, bool forceSRGB)
{
    
    // Load the materials
    const uint64 numMaterials = scene->mNumMaterials;
    for(uint64 i = 0; i < numMaterials; ++i)
    {
        MeshMaterial material;
        const aiMaterial& mat = *scene->mMaterials[i];

        aiString diffuseTexPath;
        aiString normalMapPath;
        aiString roughnessMapPath;
        aiString metallicMapPath;
        if(mat.GetTexture(aiTextureType_DIFFUSE, 0, &diffuseTexPath) == aiReturn_SUCCESS)
            material.DiffuseMapName = GetFileName(AnsiToWString(diffuseTexPath.C_Str()).c_str());

        if(mat.GetTexture(aiTextureType_NORMALS, 0, &normalMapPath) == aiReturn_SUCCESS
           || mat.GetTexture(aiTextureType_HEIGHT, 0, &normalMapPath) == aiReturn_SUCCESS)
            material.NormalMapName = GetFileName(AnsiToWString(normalMapPath.C_Str()).c_str());

        if(mat.GetTexture(aiTextureType_SHININESS, 0, &roughnessMapPath) == aiReturn_SUCCESS)
            material.RoughnessMapName = GetFileName(AnsiToWString(roughnessMapPath.C_Str()).c_str());

        if(mat.GetTexture(aiTextureType_AMBIENT, 0, &metallicMapPath) == aiReturn_SUCCESS)
            material.MetallicMapName = GetFileName(AnsiToWString(metallicMapPath.C_Str()).c_str());

        LoadMaterialResources(material, fileDirectory, device, forceSRGB);

        meshMaterials.push_back(material);
    }

    // Initialize the meshes
    const uint64 numMeshes = scene->mNumMeshes;
    meshes.resize(numMeshes);
    for(uint64 i = 0; i < numMeshes; ++i)
        meshes[i].InitFromAssimpMesh(device, *scene->mMeshes[i]);
}

void Mesh::InitFromSceneMesh(ID3D11Device *device, const MeshData& meshdata)
{

}