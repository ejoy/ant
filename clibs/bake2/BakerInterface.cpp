#include "BakerInterface.h"

#include "Meshbaker/BakingLab/BakingLab.h"
#include "Meshbaker/BakingLab/AppSettings.h"

#include <functional>

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
        AppSettings::EnableSun.SetValue(true);
        AppSettings::SunTintColor.SetValue(Float3(l.color.x, l.color.y, l.color.z));
        AppSettings::SunDirection.SetValue(Float3(l.dir.x, l.dir.y, l.dir.z));
    } else {
        AppSettings::EnableSun.SetValue(false);
        AppSettings::BakeDirectSunLight.SetValue(false);
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

static inline const char*
src_ptr(const BufferData &b, size_t idx){
    return b.data + b.offset + idx * b.stride;
}

void Mesh::InitFromSceneMesh(ID3D11Device *device, const MeshData& meshdata)
{
    numVertices = meshdata.vertexCount;
    numIndices = meshdata.indexCount;

    assert(meshdata.indexCount > 0 && meshdata.indices.type != BT_None);

    indexType = meshdata.indices.type == BT_Uint16 ? IndexType::Index16Bit : IndexType::Index32Bit;
    uint32 indexSize = meshdata.indices.type == BT_Uint16 ? 2 : 4;

    // Figure out the vertex layout
    D3D11_INPUT_ELEMENT_DESC elemDesc;
    elemDesc.InputSlot = 0;
    elemDesc.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    elemDesc.InstanceDataStepRate = 0;

    struct buffer {
        const BufferData *b;
        std::function<void (uint8* dst, const BufferData &b, size_t vidx)> f;
    };
    std::vector<buffer> buffers;

    auto default_copy = [=](auto dst, auto b, size_t vidx, uint32 n){
        assert(b.type == BT_Float);
        auto src = src_ptr(b, vidx);
        memcpy(dst, src, n * sizeof(float));
    };

    auto transform_pt = [](const auto &m, auto dst, auto b, size_t vidx, uint32 n){
        assert(b.type == BT_Float);
        assert(n == 3);
        glm::vec3* src = (glm::vec3*)src_ptr(b, vidx);
        glm::vec4 v = m * glm::vec4(*src, 1.0f);
        memcpy(dst, &v.x, sizeof(float)*3);
    };

    const glm::mat3 nm = meshdata.normalmat;
    auto transform_vec = [](const auto &m, auto dst, auto b, size_t vidx, uint32 n){
        assert(b.type == BT_Float);
        assert(n == 3);
        glm::vec3 *src = (glm::vec3*)src_ptr(b, vidx);
        auto v = m * *src;
        memcpy(dst, &v.x, sizeof(float)*3);
    };

    assert(meshdata.positions.type == BT_Float);

    vertexStride = 0;
    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = vertexStride;
    elemDesc.SemanticName = "POSITION";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexStride += 12;
    buffers.push_back(buffer{&meshdata.positions, std::bind(transform_pt, meshdata.worldmat, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, 3)});

    assert(meshdata.normals.type == BT_Float);
    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = vertexStride;
    elemDesc.SemanticName = "NORMAL";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexStride += 12;

    buffers.push_back(buffer{&meshdata.normals, std::bind(transform_vec, nm, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, 3)});
    assert(meshdata.texcoords0.type == BT_Float);

    elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
    elemDesc.AlignedByteOffset = vertexStride;
    elemDesc.SemanticName = "TEXCOORD";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexStride += 8;
    buffers.push_back(buffer{&meshdata.texcoords0, std::bind(default_copy, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, 2)});

    assert(meshdata.texcoords1.type == BT_Float);
    elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
    elemDesc.AlignedByteOffset = vertexStride;
    elemDesc.SemanticName = "TEXCOORD";
    elemDesc.SemanticIndex = 1;
    inputElements.push_back(elemDesc);
    vertexStride += 8;
    buffers.push_back(buffer{&meshdata.texcoords1, std::bind(default_copy, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, 2)});

    if (meshdata.tangents.type != BT_None && meshdata.bitangents.type != BT_None){
        elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
        elemDesc.AlignedByteOffset = vertexStride;
        elemDesc.SemanticName = "TANGENT";
        elemDesc.SemanticIndex = 0;
        inputElements.push_back(elemDesc);
        vertexStride += 12;
        buffers.push_back(buffer{&meshdata.tangents, std::bind(transform_vec, nm, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, 3)});

        elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
        elemDesc.AlignedByteOffset = vertexStride;
        elemDesc.SemanticName = "BITANGENT";
        elemDesc.SemanticIndex = 0;
        inputElements.push_back(elemDesc);
        vertexStride += 12;
        buffers.push_back(buffer{&meshdata.bitangents, std::bind(transform_vec, nm, std::placeholders::_1, std::placeholders::_2, std::placeholders::_3, 3)});
    }

    // Copy and interleave the vertex data
    vertices.resize(vertexStride * numVertices);
    for(uint64 vtxIdx = 0; vtxIdx < numVertices; ++vtxIdx)
    {
        uint8* vtxStart = &vertices[vtxIdx * vertexStride];
        for(uint64 elemIdx = 0; elemIdx < inputElements.size(); ++elemIdx)
        {
            const auto &ie = inputElements[elemIdx];

            auto buffer = buffers[elemIdx];
            buffer.f(vtxStart + ie.AlignedByteOffset, *(buffer.b), vtxIdx);
        }
    }

    // Copy the index data
    size_t indexSizeBytes = indexSize * numIndices;
    indices.resize(indexSizeBytes);
    memcpy(indices.data(), meshdata.indices.data, indexSizeBytes);

    if (meshdata.tangents.type == BT_None || meshdata.bitangents.type == BT_None)
        GenerateTangentFrame();

    CreateVertexAndIndexBuffers(device);

    const uint32 numSubsets = 1;
    meshParts.resize(numSubsets);
    auto &mp = meshParts.back();
    mp.IndexStart  = 0;
    mp.IndexCount  = numIndices;
    mp.VertexStart = 0;
    mp.VertexCount = numVertices;
    mp.MaterialIdx = meshdata.materialidx;
}