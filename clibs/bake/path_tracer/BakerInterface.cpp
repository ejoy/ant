#include "BakerInterface.h"

#include "../Meshbaker/BakingLab/BakingLab.h"
#include "../Meshbaker/BakingLab/AppSettings.h"

#include <functional>

static inline uint32_t _FindDirectionalLight(const Scene *scene){
    for (uint32_t idx=0; idx<scene->lights.size(); ++idx){
        auto l = scene->lights[idx];
        if (l.type == Light::LT_Directional){
            return idx;
        }

        assert(false && "not support other light right now");
    }

    return UINT32_MAX;
}

BakerHandle CreateBaker(const Scene* scene){
    auto bl = new BakingLab();
    bl->Init(scene);

    AppSettings::BakeMode.SetValue(BakeModes::Diffuse);

    auto lidx = _FindDirectionalLight(scene);
    if (lidx != UINT32_MAX){
        AppSettings::EnableDirectLighting.SetValue(true);
        AppSettings::BakeDirectSunLight.SetValue(true);
        AppSettings::EnableSun.SetValue(true);

        const auto& l = scene->lights[lidx];
        // if (l.size != 0){
        //     AppSettings::SunSize.SetValue(l.size);
        // }
        // AppSettings::SunTintColor.SetValue(Float3(l.color.x, l.color.y, l.color.z));
        // AppSettings::SunDirection.SetValue(Float3(l.dir.x, l.dir.y, l.dir.z));
    } else {
        AppSettings::EnableSun.SetValue(false);
        AppSettings::BakeDirectSunLight.SetValue(false);
        AppSettings::EnableDirectLighting.SetValue(false);
    }

    // AppSettings::EnableSun.SetValue(true);
    // AppSettings::EnableDirectLighting.SetValue(true);
    // AppSettings::BakeDirectSunLight.SetValue(true);
    AppSettings::SkyMode.SetValue(SkyModes::Simple);
    AppSettings::SkyColor.SetValue(Float3(4500.0000f, 4500.0000f, 4500.0000f));

    AppSettings::EnableIndirectLighting.SetValue(true);
    AppSettings::EnableIndirectSpecular.SetValue(true);

    return bl;
}

static_assert(sizeof(glm::vec4) == sizeof(Float4), "glm::vec4 must equal Float4");

void Bake(BakerHandle handle, BakeResult *result){
    auto bl = (BakingLab*)handle;
    const auto &meshes = bl->GetModel(0).Meshes();
    result->lightmaps.resize(meshes.size());
    for (uint32_t bakeMeshIdx=0; bakeMeshIdx<meshes.size(); ++bakeMeshIdx){
        auto lmsize = meshes[bakeMeshIdx].GetLightmapSize();
        if (lmsize > 0){
            AppSettings::LightMapResolution.SetValue(lmsize);
        }
        bl->Bake(bakeMeshIdx);
        auto &lm = result->lightmaps[bakeMeshIdx];
        const auto& r = bl->GetBakeResult(0);
        lm.data.resize(r.Size());
        memcpy(lm.data.data(), r.Data(), r.Size()*sizeof(Float4));
        lm.size = lmsize;
    }
}

void DestroyBaker(BakerHandle handle){
    auto bl = (BakingLab*)handle;
    bl->ShutDown();

    delete bl;
}

#include "../Meshbaker/SampleFramework11/v1.02/Graphics/Model.h"
#include "../Meshbaker/SampleFramework11/v1.02/FileIO.h"

//static
void BakingLab::InitLights(const Scene *s, Lights &lights)
{
    lights.reserve(s->lights.size());
    for (const auto &l : s->lights)
    {
        lights.emplace_back(LightData {
            Float3(l.pos.x, l.pos.y, l.pos.z),
            Float3(l.dir.x, l.dir.y, l.dir.z),
            Float3(l.color.x, l.color.y, l.color.z),
            l.intensity,
            l.range,
            l.inner_cutoff,
            l.outter_cutoff,
            l.angular_radius,
            LightData::LightType(l.type),
        });
    }
}

void Model::CreateFromScene(ID3D11Device *device, const Scene *scene, bool forceSRGB)
{
    for(auto &m : scene->materials)
    {
        MeshMaterial material;
        auto diffuse = AnsiToWString(m.diffuse.c_str());
        auto dir = GetDirectoryFromFilePath(diffuse.c_str());
        material.DiffuseMapName = GetFileName(diffuse.c_str());

        auto get_name = [&dir](const auto& fn, auto &n){
            if (!fn.empty()){
                auto nn = AnsiToWString(fn.c_str());
                assert(dir == GetDirectoryFromFilePath(nn.c_str()));
                n = GetFileName(nn.c_str());
            }
        };

        get_name(m.normal, material.NormalMapName);
        get_name(m.roughness, material.RoughnessMapName);
        get_name(m.metallic, material.MetallicMapName);

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

struct VertexData{
    Float3 pos;
    Float3 normal;
    Float2 texcoord0;
    Float2 lightmapuv;
    Float3 tangent;
    Float3 bitangent;
};

static void GenerateTangentAndBitangents(VertexData *vertices, uint32 numVertices, const BufferData &indices, uint32 numIndices)
{
    // Compute the tangent frame for each vertex. The following code is based on
    // "Computing Tangent Space Basis Vectors for an Arbitrary Mesh", by Eric Lengyel
    // http://www.terathon.com/code/tangent.html

    typedef std::function<uint32 (const BufferData &, uint32)> index_op;
    index_op get_index16 = [](const auto& indices, uint32 idx){
        return uint32(*((const uint16*)indices.data + idx));
    };
    index_op get_index32 = [](const auto& indices, uint32 idx){
        return (*(const uint32*)indices.data + idx);
    };

    index_op get_index = indices.type == BT_Uint16 ? (get_index16) : (get_index32);

    for (uint32 i = 0; i < numIndices; i += 3)
    {
        uint32 i1 = get_index(indices, i + 0);
        uint32 i2 = get_index(indices, i + 1);
        uint32 i3 = get_index(indices, i + 2);

        const Float3& v1 = vertices[i1].pos;
        const Float3& v2 = vertices[i2].pos;
        const Float3& v3 = vertices[i3].pos;

        const Float2& w1 = vertices[i1].lightmapuv;
        const Float2& w2 = vertices[i2].lightmapuv;
        const Float2& w3 = vertices[i3].lightmapuv;

        float x1 = v2.x - v1.x;
        float x2 = v3.x - v1.x;
        float y1 = v2.y - v1.y;
        float y2 = v3.y - v1.y;
        float z1 = v2.z - v1.z;
        float z2 = v3.z - v1.z;

        float s1 = w2.x - w1.x;
        float s2 = w3.x - w1.x;
        float t1 = w2.y - w1.y;
        float t2 = w3.y - w1.y;

        float r = 1.0f / (s1 * t2 - s2 * t1);
        Float3 sDir((t2 * x1 - t1 * x2) * r, (t2 * y1 - t1 * y2) * r, (t2 * z1 - t1 * z2) * r);
        Float3 tDir((s1 * x2 - s2 * x1) * r, (s1 * y2 - s2 * y1) * r, (s1 * z2 - s2 * z1) * r);

        vertices[i1].tangent += sDir;
        vertices[i2].tangent += sDir;
        vertices[i3].tangent += sDir;

        vertices[i1].bitangent += tDir;
        vertices[i2].bitangent += tDir;
        vertices[i3].bitangent += tDir;
    }

    for (uint32 i = 0; i < numVertices; ++i)
    {
        Float3& n = vertices[i].normal;
        Float3& t = vertices[i].tangent;

        // Gram-Schmidt orthogonalize
        Float3 tangent = (t - n * Float3::Dot(n, t));
        bool zeroTangent = false;
        if(tangent.Length() > 0.00001f)
            Float3::Normalize(tangent);
        else if(n.Length() > 0.00001f)
        {
            tangent = Float3::Perpendicular(n);
            zeroTangent = true;
        }

        float sign = 1.0f;

        if(!zeroTangent)
        {
            Float3 b;
            b = Float3::Cross(n, t);
            sign = (Float3::Dot(b, vertices[i].bitangent) < 0.0f) ? -1.0f : 1.0f;
        }

        // Store the tangent + bitangent
        vertices[i].tangent = Float3::Normalize(tangent);

        vertices[i].bitangent = Float3::Normalize(Float3::Cross(n, tangent));
        vertices[i].bitangent *= sign;
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
    D3D11_INPUT_ELEMENT_DESC elemDesc;
    elemDesc.InputSlot = 0;
    elemDesc.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    elemDesc.InstanceDataStepRate = 0;

    struct buffer {
        const BufferData *b;
        std::function<void (uint8* dst, const BufferData &b, size_t vidx)> f;
    };
    std::vector<buffer> buffers;

    auto transform_pt = [](const glm::mat4 &m, const BufferData& b, size_t vidx){
        assert(b.type == BT_Float);
        const glm::vec3* v = (const glm::vec3*)src_ptr(b, vidx);
        const auto r = m * glm::vec4(*v, 1.0f);
        return Float3(r.x, r.y, r.z);
    };

    const glm::mat3 nm = meshdata.normalmat;
    auto transform_vec3 = [](const glm::mat3 &m, const BufferData& b, size_t vidx){
        assert(b.type == BT_Float);
        const glm::vec3 *v = (const glm::vec3*)src_ptr(b, vidx);
        const auto r = m * *v;
        return Float3(r.x, r.y, r.z);
    };

    assert(meshdata.positions.type == BT_Float);

    uint32 vertexOffset = 0;
    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = vertexOffset;
    elemDesc.SemanticName = "POSITION";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexOffset += 12;

    assert(meshdata.normals.type == BT_Float);
    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = vertexOffset;
    elemDesc.SemanticName = "NORMAL";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexOffset += 12;

    assert(meshdata.texcoords0.type == BT_Float);

    elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
    elemDesc.AlignedByteOffset = vertexOffset;
    elemDesc.SemanticName = "TEXCOORD";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexOffset += 8;

    assert(meshdata.texcoords1.type == BT_Float);
    elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
    elemDesc.AlignedByteOffset = vertexOffset;
    elemDesc.SemanticName = "TEXCOORD";
    elemDesc.SemanticIndex = 1;
    inputElements.push_back(elemDesc);
    vertexOffset += 8;

    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = vertexOffset;
    elemDesc.SemanticName = "TANGENT";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexOffset += 12;

    elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
    elemDesc.AlignedByteOffset = vertexOffset;
    elemDesc.SemanticName = "BITANGENT";
    elemDesc.SemanticIndex = 0;
    inputElements.push_back(elemDesc);
    vertexOffset += 12;

    vertexStride = sizeof(VertexData);
    // Copy and interleave the vertex data
    vertices.resize(sizeof(VertexData) * numVertices);
    auto vd = (VertexData*)vertices.data();

    for(uint64 vtxIdx = 0; vtxIdx < numVertices; ++vtxIdx)
    {
        auto &v = vd[vtxIdx];
        v.pos = transform_pt(meshdata.worldmat, meshdata.positions, vtxIdx);
        v.normal = transform_vec3(nm, meshdata.normals, vtxIdx);
        v.texcoord0 = *(const Float2*)src_ptr(meshdata.texcoords0, vtxIdx);
        v.lightmapuv = *(const Float2*)src_ptr(meshdata.texcoords1, vtxIdx);

        if (meshdata.tangents.type != BT_None && meshdata.bitangents.type != BT_None){
            v.tangent = transform_vec3(nm, meshdata.tangents, vtxIdx);
            v.bitangent = transform_vec3(nm, meshdata.bitangents, vtxIdx);
        }
    }

    // Copy the index data
    size_t indexSizeBytes = indexSize * numIndices;
    indices.resize(indexSizeBytes);
    memcpy(indices.data(), meshdata.indices.data, indexSizeBytes);

    if (meshdata.tangents.type == BT_None || meshdata.bitangents.type == BT_None)
        GenerateTangentAndBitangents(vd, numVertices, meshdata.indices, numIndices);

    CreateVertexAndIndexBuffers(device);

    const uint32 numSubsets = 1;
    meshParts.resize(numSubsets);
    auto &mp = meshParts.back();
    mp.IndexStart  = 0;
    mp.IndexCount  = numIndices;
    mp.VertexStart = 0;
    mp.VertexCount = numVertices;
    mp.MaterialIdx = meshdata.materialidx;

    lightmapSize = meshdata.lightmap.size;
}