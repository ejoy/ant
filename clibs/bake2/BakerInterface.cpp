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
#include "Meshbaker/SampleFramework11/v1.02/FileIO.h"
void Model::CreateFromScene(ID3D11Device *device, const Scene *scene, bool forceSRGB)
{
    for(auto &m : scene->materials)
    {
        MeshMaterial material;
        auto diffuse = AnsiToWString(m.diffuse.c_str());
        auto dir = GetDirectoryFromFilePath(diffuse.c_str());
        material.DiffuseMapName = GetFileName(diffuse.c_str());

        auto normal = AnsiToWString(m.normal.c_str());
        assert(dir == GetDirectoryFromFilePath(normal.c_str()));
        material.NormalMapName = GetFileName(normal.c_str());

        if (!m.roughness.empty()){
            auto roughness = AnsiToWString(m.roughness.c_str());
            assert(dir == GetDirectoryFromFilePath(roughness.c_str()));
            material.RoughnessMapName = GetFileName(roughness.c_str());
        }

        if (!m.metallic.empty()){
            auto metallic = AnsiToWString(m.metallic.c_str());
            assert(dir == GetDirectoryFromFilePath(metallic.c_str()));
            material.MetallicMapName = GetFileName(metallic.c_str());
        }

        LoadMaterialResources(material, dir, device, forceSRGB);

        meshMaterials.push_back(material);
    }

    // Initialize the meshes
    meshes.resize(scene->models.size());
    for (size_t i=0; i<meshes.size(); ++i){
        meshes[i].InitFromSceneMesh(device, scene->models[i]);
    }
}

void Mesh::InitFromSceneMesh(ID3D11Device *device, const MeshData& meshdata)
{
    numVertices = meshdata.vertexCount;
    numIndices = meshdata.indexCount;

    assert(meshdata.indexCount > 0 && meshdata.indices.type != BT_None);

    indexType = meshdata.indices.type == BT_Uint16 ? IndexType::Index16Bit : IndexType::Index32Bit;
    uint32 indexSize = meshdata.indices.type == BT_Uint16 ? 2 : 4;

    // Figure out the vertex layout
    uint32 currOffset = 0;
    D3D11_INPUT_ELEMENT_DESC elemDesc;
    elemDesc.InputSlot = 0;
    elemDesc.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    elemDesc.InstanceDataStepRate = 0;

    std::vector<const BufferData*> buffers;

    assert(meshdata.positions.type == BT_Float);

    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = currOffset;
    elemDesc.SemanticName = "POSITION";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    currOffset += 12;
    buffers.push_back(&meshdata.positions);

    assert(meshdata.normals.type == BT_Float);
    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = currOffset;
    elemDesc.SemanticName = "NORMAL";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    currOffset += 12;

    buffers.push_back(&meshdata.normals);

    assert(meshdata.texcoords0.type == BT_Float);

    elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
    elemDesc.AlignedByteOffset = currOffset;
    elemDesc.SemanticName = "TEXCOORD";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    currOffset += 8;
    buffers.push_back(&meshdata.texcoords0);

    assert(meshdata.texcoords1.type == BT_Float);
    elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
    elemDesc.AlignedByteOffset = currOffset;
    elemDesc.SemanticName = "TEXCOORD";
    elemDesc.SemanticIndex = 1;
    inputElements.push_back(elemDesc);
    currOffset += 8;
    buffers.push_back(&meshdata.texcoords1);

    // if(assimpMesh.HasTangentsAndBitangents())
    // {
    //     elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    //     elemDesc.AlignedByteOffset = currOffset;
    //     elemDesc.SemanticName = "TANGENT";
    //     elemDesc.SemanticIndex = 0;
    //     inputElements.push_back(elemDesc);
    //     currOffset += 12;
    //     vertexData.push_back(assimpMesh.mTangents);

    //     elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    //     elemDesc.AlignedByteOffset = currOffset;
    //     elemDesc.SemanticName = "BITANGENT";
    //     elemDesc.SemanticIndex = 0;
    //     inputElements.push_back(elemDesc);
    //     currOffset += 12;
    //     vertexData.push_back(assimpMesh.mBitangents);
    // }

    // vertexStride = currOffset;

    // // Copy and interleave the vertex data
    // vertices.resize(vertexStride * numVertices, 0);
    // for(uint64 vtxIdx = 0; vtxIdx < numVertices; ++vtxIdx)
    // {
    //     uint8* vtxStart = &vertices[vtxIdx * vertexStride];
    //     for(uint64 elemIdx = 0; elemIdx < inputElements.size(); ++elemIdx)
    //     {
    //         uint64 offset = inputElements[elemIdx].AlignedByteOffset;
    //         uint64 elemSize = elemIdx == inputElements.size() - 1 ? vertexStride - offset :
    //                                                                 inputElements[elemIdx + 1].AlignedByteOffset - offset;
    //         uint8* elemStart = vtxStart + inputElements[elemIdx].AlignedByteOffset;
    //         memcpy(elemStart, vertexData[elemIdx] + vtxIdx, elemSize);

    //         if(vertexData[elemIdx] == assimpMesh.mBitangents)
    //             *reinterpret_cast<Float3*>(elemStart) *= -1.0f;
    //     }
    // }

    // // Copy the index data
    // indices.resize(indexSize * numIndices, 0);
    // const uint64 numTriangles = assimpMesh.mNumFaces;
    // for(uint64 triIdx = 0; triIdx < numTriangles; ++triIdx)
    // {
    //     void* triStart = &indices[triIdx * 3 * indexSize];
    //     const aiFace& tri = assimpMesh.mFaces[triIdx];
    //     if(indexType == IndexType::Index32Bit)
    //         memcpy(triStart, tri.mIndices, sizeof(uint32) * 3);
    //     else
    //     {
    //         uint16* triIndices = reinterpret_cast<uint16*>(triStart);
    //         for(uint64 i = 0; i < 3; ++i)
    //             triIndices[i] = uint16(tri.mIndices[i]);
    //     }
    // }

    // CreateVertexAndIndexBuffers(device);

    // const uint32 numSubsets = 1;
    // meshParts.resize(numSubsets);
    // for(uint32 i = 0; i < numSubsets; ++i)
    // {
    //     MeshPart& part = meshParts[i];
    //     part.IndexStart = 0;
    //     part.IndexCount = numIndices;
    //     part.VertexStart = 0;
    //     part.VertexCount = numVertices;
    //     part.MaterialIdx = assimpMesh.mMaterialIndex;
    // }
}