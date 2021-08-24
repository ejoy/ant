//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#pragma once

#include "..\\PCH.h"

#include "..\\InterfacePointers.h"
#include "..\\SF11_Math.h"
#include "..\\Serialization.h"

struct aiMesh;

namespace SampleFramework11
{

class SDKMesh;

struct MeshMaterial
{
    std::wstring DiffuseMapName;
    std::wstring NormalMapName;
    std::wstring RoughnessMapName;
    std::wstring MetallicMapName;
    ID3D11ShaderResourceViewPtr DiffuseMap;
    ID3D11ShaderResourceViewPtr NormalMap;
    ID3D11ShaderResourceViewPtr RoughnessMap;
    ID3D11ShaderResourceViewPtr MetallicMap;

    template<typename TSerializer> void Serialize(TSerializer& serializer)
    {
        SerializeItem(serializer, DiffuseMapName);
        SerializeItem(serializer, NormalMapName);
        SerializeItem(serializer, RoughnessMapName);
        SerializeItem(serializer, MetallicMapName);
    }
};

struct MeshPart
{
    uint32 VertexStart;
    uint32 VertexCount;
    uint32 IndexStart;
    uint32 IndexCount;
    uint32 MaterialIdx;

    MeshPart() : VertexStart(0), VertexCount(0), IndexStart(0), IndexCount(0), MaterialIdx(0)
    {
    }
};

enum class IndexType
{
    Index16Bit = 0,
    Index32Bit = 1
};

class Mesh
{
    friend class Model;

public:

    // Init from loaded files
    void InitFromSDKMesh(ID3D11Device* device, SDKMesh& sdkmesh, uint32 meshIdx, bool generateTangents);
    void InitFromAssimpMesh(ID3D11Device* device, const aiMesh& assimpMesh);

    // Procedural generation
    void InitBox(ID3D11Device* device, const Float3& dimensions, const Float3& position,
                 const Quaternion& orientation, uint32 materialIdx);

    void InitPlane(ID3D11Device* device, const Float2& dimensions, const Float3& position,
                   const Quaternion& orientation, uint32 materialIdx);

    void InitCornea(ID3D11Device* device, uint32 materialIdx);

    // Rendering
    void Render(ID3D11DeviceContext* context);

    // Accessors
    ID3D11Buffer* VertexBuffer() const { return vertexBuffer; }
    ID3D11Buffer* IndexBuffer() const { return indexBuffer; }

    std::vector<MeshPart>& MeshParts() { return meshParts; }
    const std::vector<MeshPart>& MeshParts() const { return meshParts; }

    const D3D11_INPUT_ELEMENT_DESC* InputElements() const { return &inputElements[0]; }
    uint32 NumInputElements() const { return static_cast<uint32>(inputElements.size()); }

    uint32 VertexStride() const { return vertexStride; }
    uint32 NumVertices() const { return numVertices; }
    uint32 NumIndices() const { return numIndices; }

    IndexType IndexBufferType() const { return indexType; }
    DXGI_FORMAT IndexBufferFormat() const { return indexType == IndexType::Index32Bit ? DXGI_FORMAT_R32_UINT : DXGI_FORMAT_R16_UINT; }
    uint32 IndexSize() const { return indexType == IndexType::Index32Bit ? 4 : 2; }

    const uint8* Vertices() const { return vertices.data(); }
    const uint8* Indices() const { return indices.data(); }

    template<typename TSerializer> void Serialize(TSerializer& serializer)
    {
        SerializeRawVector(serializer, meshParts);

        inputElementStrings.resize(inputElements.size());
        for(uint64 i = 0; i < inputElements.size(); ++i)
            inputElementStrings[i] = std::string(inputElements[i].SemanticName);

        SerializeRawVector(serializer, inputElements);
        SerializeItem(serializer, inputElementStrings);

        for(uint64 i = 0; i < inputElements.size(); ++i)
            inputElements[i].SemanticName = inputElementStrings[i].c_str();

        SerializeItem(serializer, vertexStride);
        SerializeItem(serializer, numVertices);
        SerializeItem(serializer, numIndices);
        uint32 idxType = uint32(indexType);
        SerializeItem(serializer, idxType);
        indexType = IndexType(idxType);
        SerializeRawVector(serializer, vertices);
        SerializeRawVector(serializer, indices);
    }

protected:

    void GenerateTangentFrame();
    void CreateInputElements(const D3DVERTEXELEMENT9* declaration);
    void CreateVertexAndIndexBuffers(ID3D11Device* device);

    ID3D11BufferPtr vertexBuffer;
    ID3D11BufferPtr indexBuffer;

    std::vector<MeshPart> meshParts;
    std::vector<D3D11_INPUT_ELEMENT_DESC> inputElements;
    std::vector<std::string> inputElementStrings;

    uint32 vertexStride = 0;
    uint32 numVertices = 0;
    uint32 numIndices = 0;

    IndexType indexType = IndexType::Index16Bit;

    std::vector<uint8> vertices;
    std::vector<uint8> indices;
};

class Model
{
public:

    // Loading from file formats
    void CreateFromSDKMeshFile(ID3D11Device* device, const wchar* fileName,
                                const wchar* normalMapSuffix = NULL,
                                bool generateTangentFrame = false,
                                bool overrideNormalMaps = false,
                                bool forceSRGB = false);

    void CreateWithAssimp(ID3D11Device* device, const wchar* fileName, bool forceSRGB = false);

    void CreateFromMeshData(ID3D11Device* device, const wchar* fileName, bool forceSRGB = false);

    // Procedural generation
    void GenerateBoxScene(ID3D11Device* device,
                          const Float3& dimensions = Float3(1.0f, 1.0f, 1.0f),
                          const Float3& position = Float3(),
                          const Quaternion& orientation = Quaternion(),
                          const wchar* colorMap = L"",
                          const wchar* normalMap = L"");
    void GenerateBoxTestScene(ID3D11Device* device);
    void GeneratePlaneScene(ID3D11Device* device,
                            const Float2& dimensions = Float2(1.0f, 1.0f),
                            const Float3& position = Float3(),
                            const Quaternion& orientation = Quaternion(),
                            const wchar* colorMap = L"",
                            const wchar* normalMap = L"");
    void GenerateCorneaScene(ID3D11Device* device);

    // Accessors
    std::vector<MeshMaterial>& Materials() { return meshMaterials; };
    const std::vector<MeshMaterial>& Materials() const { return meshMaterials; };

    std::vector<Mesh>& Meshes() { return meshes; }
    const std::vector<Mesh>& Meshes() const { return meshes; }

    // Serialization
    template<typename TSerializer>
    void Serialize(TSerializer& serializer, ID3D11Device* device, bool forceSRGB = false)
    {
        SerializeItem(serializer, meshes);
        SerializeItem(serializer, meshMaterials);
        SerializeItem(serializer, fileDirectory);

        if(TSerializer::IsReadSerializer())
        {
            for(uint64 i = 0; i  < meshes.size(); ++i)
                meshes[i].CreateVertexAndIndexBuffers(device);

            for(uint64 i = 0; i < meshMaterials.size(); ++i)
                LoadMaterialResources(meshMaterials[i], fileDirectory, device, forceSRGB);
        }
    }

protected:

    static void LoadMaterialResources(MeshMaterial& material, const std::wstring& directory, ID3D11Device* device, bool forceSRGB);

    std::vector<Mesh> meshes;
    std::vector<MeshMaterial> meshMaterials;
    std::wstring fileDirectory;
};

}