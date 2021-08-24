//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "PCH.h"

#include "Model.h"

#include "SDKmesh.h"
#include "..\\Exceptions.h"
#include "..\\Utility.h"
#include "GraphicsTypes.h"
#include "..\\Serialization.h"
#include "..\\FileIO.h"
#include "Textures.h"

using std::string;
using std::wstring;
using std::vector;
using std::map;
using std::wifstream;

namespace SampleFramework11
{

struct Vertex
{
    Float3 Position;
    Float3 Normal;
    Float2 TexCoord;
    Float3 Tangent;
    Float3 Bitangent;

    Vertex()
    {
    }

    Vertex(const Float3& p, const Float3& n, const Float2& tc, const Float3& t, const Float3& b)
    {
        Position = p;
        Normal = n;
        TexCoord = tc;
        Tangent = t;
        Bitangent = b;
    }

    void Transform(const Float3& p, const Float3& s, const Quaternion& q)
    {
        Position *= s;
        Position = Float3::Transform(Position, q);
        Position += p;

        Normal = Float3::Transform(Normal, q);
        Tangent = Float3::Transform(Tangent, q);
        Bitangent = Float3::Transform(Bitangent, q);
    }
};

static const D3D11_INPUT_ELEMENT_DESC VertexInputs[5] =
{
    { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "NORMAL", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT, 0, 24, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "TANGENT", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 32, D3D11_INPUT_PER_VERTEX_DATA, 0 },
    { "BITANGENT", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 44, D3D11_INPUT_PER_VERTEX_DATA, 0 },
};

void Mesh::InitFromSDKMesh(ID3D11Device* device, SDKMesh& sdkMesh, uint32 meshIdx, bool generateTangents)
{
    const SDKMESH_MESH& sdkMeshData = *sdkMesh.GetMesh(meshIdx);

    uint32 indexSize = 2;
    indexType = IndexType::Index16Bit;
    if(sdkMesh.GetIndexType(meshIdx) == IT_32BIT)
    {
        indexSize = 4;
        indexType = IndexType::Index32Bit;
    }

    vertexStride = sdkMesh.GetVertexStride(meshIdx, 0);
    numVertices = static_cast<uint32>(sdkMesh.GetNumVertices(meshIdx, 0));
    numIndices = static_cast<uint32>(sdkMesh.GetNumIndices(meshIdx));
    const uint32 vbIdx = sdkMeshData.VertexBuffers[0];
    const uint32 ibIdx = sdkMeshData.IndexBuffer;

    CreateInputElements(sdkMesh.VBElements(0));

    vertices.resize(vertexStride * numVertices, 0);
    memcpy(vertices.data(), sdkMesh.GetRawVerticesAt(vbIdx), vertexStride * numVertices);

    indices.resize(indexSize * numIndices, 0);
    memcpy(indices.data(), sdkMesh.GetRawIndicesAt(ibIdx), indexSize * numIndices);

    if(generateTangents)
        GenerateTangentFrame();

    CreateVertexAndIndexBuffers(device);

    const uint32 numSubsets = sdkMesh.GetNumSubsets(meshIdx);
    meshParts.resize(numSubsets);
    for(uint32 i = 0; i < numSubsets; ++i)
    {
        const SDKMESH_SUBSET& subset = *sdkMesh.GetSubset(meshIdx, i);
        MeshPart& part = meshParts[i];
        part.IndexStart = static_cast<uint32>(subset.IndexStart);
        part.IndexCount = static_cast<uint32>(subset.IndexCount);
        part.VertexStart = static_cast<uint32>(subset.VertexStart);
        part.VertexCount = static_cast<uint32>(subset.VertexCount);
        part.MaterialIdx = subset.MaterialID;
    }
}

void Mesh::InitFromAssimpMesh(ID3D11Device* device, const aiMesh& assimpMesh)
{
    numVertices = assimpMesh.mNumVertices;
    numIndices = assimpMesh.mNumFaces * 3;

    uint32 indexSize = 2;
    indexType = IndexType::Index16Bit;
    if(numVertices > 0xFFFF)
    {
        indexSize = 4;
        indexType = IndexType::Index32Bit;
    }

    // Figure out the vertex layout
    uint32 currOffset = 0;
    D3D11_INPUT_ELEMENT_DESC elemDesc;
    elemDesc.InputSlot = 0;
    elemDesc.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
    elemDesc.InstanceDataStepRate = 0;
    std::vector<const aiVector3D*> vertexData;

    if(assimpMesh.HasPositions())
    {
        elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
        elemDesc.AlignedByteOffset = currOffset;
        elemDesc.SemanticName = "POSITION";
        elemDesc.SemanticIndex = 0;
        inputElements.push_back(elemDesc);
        currOffset += 12;
        vertexData.push_back(assimpMesh.mVertices);
    }

    if(assimpMesh.HasNormals())
    {
        elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
        elemDesc.AlignedByteOffset = currOffset;
        elemDesc.SemanticName = "NORMAL";
        elemDesc.SemanticIndex = 0;
        inputElements.push_back(elemDesc);
        currOffset += 12;
        vertexData.push_back(assimpMesh.mNormals);
    }

    for(uint32 i = 0; i < AI_MAX_NUMBER_OF_TEXTURECOORDS; ++i)
    {
        if(assimpMesh.HasTextureCoords(i))
        {
            elemDesc.Format = DXGI_FORMAT_R32G32_FLOAT;
            elemDesc.AlignedByteOffset = currOffset;
            elemDesc.SemanticName = "TEXCOORD";
            elemDesc.SemanticIndex = i;
            inputElements.push_back(elemDesc);
            currOffset += 8;
            vertexData.push_back(assimpMesh.mTextureCoords[i]);
        }
    }

    if(assimpMesh.HasTangentsAndBitangents())
    {
        elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
        elemDesc.AlignedByteOffset = currOffset;
        elemDesc.SemanticName = "TANGENT";
        elemDesc.SemanticIndex = 0;
        inputElements.push_back(elemDesc);
        currOffset += 12;
        vertexData.push_back(assimpMesh.mTangents);

        elemDesc.Format = DXGI_FORMAT_R32G32B32_FLOAT;
        elemDesc.AlignedByteOffset = currOffset;
        elemDesc.SemanticName = "BITANGENT";
        elemDesc.SemanticIndex = 0;
        inputElements.push_back(elemDesc);
        currOffset += 12;
        vertexData.push_back(assimpMesh.mBitangents);
    }

    vertexStride = currOffset;

    // Copy and interleave the vertex data
    vertices.resize(vertexStride * numVertices, 0);
    for(uint64 vtxIdx = 0; vtxIdx < numVertices; ++vtxIdx)
    {
        uint8* vtxStart = &vertices[vtxIdx * vertexStride];
        for(uint64 elemIdx = 0; elemIdx < inputElements.size(); ++elemIdx)
        {
            uint64 offset = inputElements[elemIdx].AlignedByteOffset;
            uint64 elemSize = elemIdx == inputElements.size() - 1 ? vertexStride - offset :
                                                                    inputElements[elemIdx + 1].AlignedByteOffset - offset;
            uint8* elemStart = vtxStart + inputElements[elemIdx].AlignedByteOffset;
            memcpy(elemStart, vertexData[elemIdx] + vtxIdx, elemSize);

            if(vertexData[elemIdx] == assimpMesh.mBitangents)
                *reinterpret_cast<Float3*>(elemStart) *= -1.0f;
        }
    }

    // Copy the index data
    indices.resize(indexSize * numIndices, 0);
    const uint64 numTriangles = assimpMesh.mNumFaces;
    for(uint64 triIdx = 0; triIdx < numTriangles; ++triIdx)
    {
        void* triStart = &indices[triIdx * 3 * indexSize];
        const aiFace& tri = assimpMesh.mFaces[triIdx];
        if(indexType == IndexType::Index32Bit)
            memcpy(triStart, tri.mIndices, sizeof(uint32) * 3);
        else
        {
            uint16* triIndices = reinterpret_cast<uint16*>(triStart);
            for(uint64 i = 0; i < 3; ++i)
                triIndices[i] = uint16(tri.mIndices[i]);
        }
    }

    CreateVertexAndIndexBuffers(device);

    const uint32 numSubsets = 1;
    meshParts.resize(numSubsets);
    for(uint32 i = 0; i < numSubsets; ++i)
    {
        MeshPart& part = meshParts[i];
        part.IndexStart = 0;
        part.IndexCount = numIndices;
        part.VertexStart = 0;
        part.VertexCount = numVertices;
        part.MaterialIdx = assimpMesh.mMaterialIndex;
    }
}

// Initializes the mesh as a box
void Mesh::InitBox(ID3D11Device* device, const Float3& dimensions, const Float3& position,
                   const Quaternion& orientation, uint32 materialIdx)
{
    const uint64 NumBoxVerts = 24;
    const uint64 NumBoxIndices = 36;

    std::vector<Vertex> boxVerts(NumBoxVerts);
    std::vector<uint16> boxIndices(NumBoxIndices, 0);

    uint64 vIdx = 0;

    // Top
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, 1.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, 1.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, 1.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, 1.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));

    // Bottom
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, -1.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, -1.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, -1.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, -1.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f));

    // Front
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, 1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, 1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, -1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, -1.0f, -1.0f), Float3(0.0f, 0.0f, -1.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));

    // Back
    boxVerts[vIdx++] = Vertex(Float3(1.0f, 1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(0.0f, 0.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, 1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(1.0f, 0.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, -1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(1.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, -1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float2(0.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float3(0.0f, -1.0f, 0.0f));

    // Left
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, 1.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, 1.0f, -1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(1.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, -1.0f, -1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(1.0f, 1.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(-1.0f, -1.0f, 1.0f), Float3(-1.0f, 0.0f, 0.0f), Float2(0.0f, 1.0f), Float3(0.0f, 0.0f, -1.0f), Float3(0.0f, -1.0f, 0.0f));

    // Right
    boxVerts[vIdx++] = Vertex(Float3(1.0f, 1.0f, -1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(0.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, 1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(1.0f, 0.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, -1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(1.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));
    boxVerts[vIdx++] = Vertex(Float3(1.0f, -1.0f, -1.0f), Float3(1.0f, 0.0f, 0.0f), Float2(0.0f, 1.0f), Float3(0.0f, 0.0f, 1.0f), Float3(0.0f, -1.0f, 0.0f));

    for(uint64 i = 0; i < NumBoxVerts; ++i)
        boxVerts[i].Transform(position, dimensions * 0.5f, orientation);

    uint64 iIdx = 0;

    // Top
    boxIndices[iIdx++] = 0;
    boxIndices[iIdx++] = 1;
    boxIndices[iIdx++] = 2;
    boxIndices[iIdx++] = 2;
    boxIndices[iIdx++] = 3;
    boxIndices[iIdx++] = 0;

    // Bottom
    boxIndices[iIdx++] = 4 + 0;
    boxIndices[iIdx++] = 4 + 1;
    boxIndices[iIdx++] = 4 + 2;
    boxIndices[iIdx++] = 4 + 2;
    boxIndices[iIdx++] = 4 + 3;
    boxIndices[iIdx++] = 4 + 0;

    // Front
    boxIndices[iIdx++] = 8 + 0;
    boxIndices[iIdx++] = 8 + 1;
    boxIndices[iIdx++] = 8 + 2;
    boxIndices[iIdx++] = 8 + 2;
    boxIndices[iIdx++] = 8 + 3;
    boxIndices[iIdx++] = 8 + 0;

    // Back
    boxIndices[iIdx++] = 12 + 0;
    boxIndices[iIdx++] = 12 + 1;
    boxIndices[iIdx++] = 12 + 2;
    boxIndices[iIdx++] = 12 + 2;
    boxIndices[iIdx++] = 12 + 3;
    boxIndices[iIdx++] = 12 + 0;

    // Left
    boxIndices[iIdx++] = 16 + 0;
    boxIndices[iIdx++] = 16 + 1;
    boxIndices[iIdx++] = 16 + 2;
    boxIndices[iIdx++] = 16 + 2;
    boxIndices[iIdx++] = 16 + 3;
    boxIndices[iIdx++] = 16 + 0;

    // Right
    boxIndices[iIdx++] = 20 + 0;
    boxIndices[iIdx++] = 20 + 1;
    boxIndices[iIdx++] = 20 + 2;
    boxIndices[iIdx++] = 20 + 2;
    boxIndices[iIdx++] = 20 + 3;
    boxIndices[iIdx++] = 20 + 0;

    const uint32 indexSize = 2;
    indexType = IndexType::Index16Bit;

    vertexStride = sizeof(Vertex);
    numVertices = uint32(NumBoxVerts);
    numIndices = uint32(NumBoxIndices);

    inputElements.clear();
    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));

    const uint32 vbSize = vertexStride * numVertices;
    vertices.resize(vbSize, 0);
    memcpy(vertices.data(), boxVerts.data(), vbSize);

    const uint32 ibSize = indexSize * numIndices;
    indices.resize(ibSize, 0);
    memcpy(indices.data(), boxIndices.data(), ibSize);

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
    bufferDesc.ByteWidth = vbSize;
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = vertices.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));

    bufferDesc.ByteWidth = ibSize;
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    initData.pSysMem = indices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));

    meshParts.resize(1);

    MeshPart& part = meshParts[0];
    part.IndexStart = 0;
    part.IndexCount = numIndices;
    part.VertexStart = 0;
    part.VertexCount = numVertices;
    part.MaterialIdx = materialIdx;
}

// Initializes the mesh as a plane
void Mesh::InitPlane(ID3D11Device* device, const Float2& dimensions, const Float3& position,
                   const Quaternion& orientation, uint32 materialIdx)
{
    const uint64 NumPlaneVerts = 4;
    const uint64 NumPlaneIndices = 6;

    std::vector<Vertex> planeVerts(NumPlaneVerts);
    std::vector<uint16> planeIndices(NumPlaneIndices, 0);

    uint64 vIdx = 0;

    planeVerts[vIdx++] = Vertex(Float3(-1.0f, 0.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    planeVerts[vIdx++] = Vertex(Float3(1.0f, 0.0f, 1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 0.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    planeVerts[vIdx++] = Vertex(Float3(1.0f, 0.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(1.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));
    planeVerts[vIdx++] = Vertex(Float3(-1.0f, 0.0f, -1.0f), Float3(0.0f, 1.0f, 0.0f), Float2(0.0f, 1.0f), Float3(1.0f, 0.0f, 0.0f), Float3(0.0f, 0.0f, -1.0f));

    for(uint64 i = 0; i < NumPlaneVerts; ++i)
        planeVerts[i].Transform(position, Float3(dimensions.x, 1.0f, dimensions.y) * 0.5f, orientation);

    uint64 iIdx = 0;
    planeIndices[iIdx++] = 0;
    planeIndices[iIdx++] = 1;
    planeIndices[iIdx++] = 2;
    planeIndices[iIdx++] = 2;
    planeIndices[iIdx++] = 3;
    planeIndices[iIdx++] = 0;

    const uint32 indexSize = 2;
    indexType = IndexType::Index16Bit;

    vertexStride = sizeof(Vertex);
    numVertices = uint32(NumPlaneVerts);
    numIndices = uint32(NumPlaneIndices);

    inputElements.clear();
    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));

    const uint32 vbSize = vertexStride * numVertices;
    vertices.resize(vbSize, 0);
    memcpy(vertices.data(), planeVerts.data(), vbSize);

    const uint32 ibSize = indexSize * numIndices;
    indices.resize(ibSize, 0);
    memcpy(indices.data(), planeIndices.data(), ibSize);

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
    bufferDesc.ByteWidth = vbSize;
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = vertices.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));

    bufferDesc.ByteWidth = ibSize;
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    initData.pSysMem = indices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));

    meshParts.resize(1);

    MeshPart& part = meshParts[0];
    part.IndexStart = 0;
    part.IndexCount = numIndices;
    part.VertexStart = 0;
    part.VertexCount = numVertices;
    part.MaterialIdx = materialIdx;
}

static float CorneaZ(float r)
{
    float x = 2028.0f - 25.0f * r * r;
    return 0.13333f * (1.73205f * std::sqrt(x) - 78.0f);
}

// Initializes the mesh as a plane
void Mesh::InitCornea(ID3D11Device* device, uint32 materialIdx)
{
    const float R = 5.5f;
    const float IrisDepth = 2.18f;

    const uint64 XRes = 100;
    const uint64 YRes = 100;
    const uint64 NumVerts = XRes * YRes;
    const uint64 NumTriangles = (XRes - 1) * (YRes - 1) * 2;
    const uint64 NumIndices = NumTriangles * 6;
    StaticAssert_(NumVerts <= UINT32_MAX);

    std::vector<Vertex> corneaVerts(NumVerts);
    std::vector<uint32> corneaIndices(NumIndices, 0);

    uint64 vIdx = 0;
    for(uint64 yIdx = 0; yIdx < YRes; ++yIdx)
    {
        for(uint64 xIdx = 0; xIdx < XRes; ++xIdx)
        {
            const float u = xIdx / (XRes - 1.0f);
            const float v = yIdx / (YRes - 1.0f);
            const float x = (u * 2.0f - 1.0f) * R;
            const float y = (v * 2.0f - 1.0f) * R;
            const float r = std::min(std::sqrt(x * x + y * y), R);
            const float z = CorneaZ(r);

            const float uStep = 1.0f / (XRes - 1.0f);
            const float vStep = 1.0f / (YRes - 1.0f);
            const float x1 = x;
            const float y1 = y;
            const float z1 = z;

            // [1, 0]
            const float v0 = v - vStep;
            const float y0 = (v0 * 2.0f - 1.0f) * R;
            const float r10 = std::min(std::sqrt(x1 * x1 + y0 * y0), R);
            const float z10 = CorneaZ(r10);

            // [2, 1]
            const float u2 = u + uStep;
            const float x2 = (u2 * 2.0f - 1.0f) * R;
            const float r21 = std::min(std::sqrt(x2 * x2 + y1 * y1), R);
            const float z21 = CorneaZ(r21);

            // [1, 2]
            const float v2 = v + vStep;
            const float y2 = (v2 * 2.0f - 1.0f) * R;
            const float r12 = std::min(std::sqrt(x1 * x1 + y2 * y2), R);
            const float z12 = CorneaZ(r12);

            // [0, 1]
            const float u0 = u - uStep;
            const float x0 = (u0 * 2.0f - 1.0f) * R;
            const float r01 = std::min(std::sqrt(x0 * x0 + y1 * y1), R);
            const float z01 = CorneaZ(r01);

            const Float3 p11 = Float3(x1, y1, z1);
            const Float3 p21 = Float3(x2, y1, z21);
            const Float3 p12 = Float3(x1, y2, z12);
            const Float3 p01 = Float3(x0, y1, z01);
            const Float3 p10 = Float3(x1, y0, z10);
            const Float3 t01 = Float3::Normalize(p11 - p01);
            const Float3 b01 = Float3::Normalize(p11 - p10);
            const Float3 t12 = Float3::Normalize(p21 - p11);
            const Float3 b12 = Float3::Normalize(p12 - p11);
            const Float3 n01 = Float3::Normalize(Float3::Cross(t01, b01));
            const Float3 n12 = Float3::Normalize(Float3::Cross(t12, b12));

            Vertex& vertex = corneaVerts[vIdx];
            vertex.Position = p11;
            vertex.Normal = (n01 + n12) / 2.0f;
            vertex.Tangent = (t01 + t12) / 2.0f;
            vertex.Bitangent = (b01 + b12) / 2.0f;
            vertex.TexCoord = Float2(u, v);
            ++vIdx;
        }
    }

    uint64 iIdx = 0;
    for(uint64 yIdx = 0; yIdx < YRes - 1; ++yIdx)
    {
        for(uint64 xIdx = 0; xIdx < XRes - 1; ++xIdx)
        {
            const uint32 i00 = uint32(yIdx * YRes + xIdx);
            const uint32 i10 = i00 + 1;
            const uint32 i01 = uint32((yIdx  + 1) * YRes + xIdx);
            const uint32 i11 = i01 + 1;
            corneaIndices[iIdx++] = i00;
            corneaIndices[iIdx++] = i10;
            corneaIndices[iIdx++] = i11;
            corneaIndices[iIdx++] = i11;
            corneaIndices[iIdx++] = i01;
            corneaIndices[iIdx++] = i00;
        }
    }

    numVertices = uint32(NumVerts);
    numIndices = uint32(NumIndices);

    const uint32 indexSize = 4;
    indexType = IndexType::Index32Bit;

    vertexStride = sizeof(Vertex);

    inputElements.clear();
    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));

    const uint32 vbSize = vertexStride * numVertices;
    vertices.resize(vbSize, 0);
    memcpy(vertices.data(), corneaVerts.data(), vbSize);

    const uint32 ibSize = indexSize * numIndices;
    indices.resize(ibSize, 0);
    memcpy(indices.data(), corneaIndices.data(), ibSize);

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
    bufferDesc.ByteWidth = vbSize;
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = vertices.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));

    bufferDesc.ByteWidth = ibSize;
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    initData.pSysMem = indices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));

    meshParts.resize(1);

    MeshPart& part = meshParts[0];
    part.IndexStart = 0;
    part.IndexCount = numIndices;
    part.VertexStart = 0;
    part.VertexCount = numVertices;
    part.MaterialIdx = materialIdx;
}


void Mesh::GenerateTangentFrame()
{
    // Make sure that we have a position + texture coordinate + normal
    uint32 posOffset = 0xFFFFFFFF;
    uint32 nmlOffset = 0xFFFFFFFF;
    uint32 tcOffset = 0xFFFFFFFF;
    for(uint32 i = 0; i < inputElements.size(); ++i)
    {
        const std::string semantic = inputElements[i].SemanticName;
        const uint32 offset = inputElements[i].AlignedByteOffset;
        if(semantic == "POSITION")
            posOffset = offset;
        else if(semantic == "NORMAL")
            nmlOffset = offset;
        else if(semantic == "TEXCOORD")
            tcOffset = offset;
    }

    if(posOffset == 0xFFFFFFFF || nmlOffset == 0xFFFFFFFF || tcOffset == 0xFFFFFFFF)
        throw Exception(L"Can't generate a tangent frame, mesh doesn't have positions, normals, and texcoords");

    // Clone the mesh
    std::vector<Vertex> newVertices(numVertices);

    const uint8* vtxData = vertices.data();
    for(uint32 i = 0; i < numVertices; ++i)
    {
        newVertices[i].Position = *reinterpret_cast<const Float3*>(vtxData + posOffset);
        newVertices[i].Normal = *reinterpret_cast<const Float3*>(vtxData + nmlOffset);
        newVertices[i].TexCoord = *reinterpret_cast<const Float2*>(vtxData + tcOffset);
        vtxData += vertexStride;
    }

    // Compute the tangent frame for each vertex. The following code is based on
    // "Computing Tangent Space Basis Vectors for an Arbitrary Mesh", by Eric Lengyel
    // http://www.terathon.com/code/tangent.html

    // Make temporary arrays for the tangent and the bitangent
    std::vector<Float3> tangents(numVertices);
    std::vector<Float3> bitangents(numVertices);

    // Loop through each triangle
    const uint32 indexSize = indexType == IndexType::Index16Bit ? 2 : 4;
    for (uint32 i = 0; i < numIndices; i += 3)
    {
        uint32 i1 = GetIndex(indices.data(), i + 0, indexSize);
        uint32 i2 = GetIndex(indices.data(), i + 1, indexSize);
        uint32 i3 = GetIndex(indices.data(), i + 2, indexSize);

        const Float3& v1 = newVertices[i1].Position;
        const Float3& v2 = newVertices[i2].Position;
        const Float3& v3 = newVertices[i3].Position;

        const Float2& w1 = newVertices[i1].TexCoord;
        const Float2& w2 = newVertices[i2].TexCoord;
        const Float2& w3 = newVertices[i3].TexCoord;

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

        tangents[i1] += sDir;
        tangents[i2] += sDir;
        tangents[i3] += sDir;

        bitangents[i1] += tDir;
        bitangents[i2] += tDir;
        bitangents[i3] += tDir;
    }

    for (uint32 i = 0; i < numVertices; ++i)
    {
        Float3& n = newVertices[i].Normal;
        Float3& t = tangents[i];

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
            sign = (Float3::Dot(b, bitangents[i]) < 0.0f) ? -1.0f : 1.0f;
        }

        // Store the tangent + bitangent
        newVertices[i].Tangent = Float3::Normalize(tangent);

        newVertices[i].Bitangent = Float3::Normalize(Float3::Cross(n, tangent));
        newVertices[i].Bitangent *= sign;
    }

    inputElements.clear();
    inputElements.resize(sizeof(VertexInputs) / sizeof(D3D11_INPUT_ELEMENT_DESC));
    memcpy(inputElements.data(), VertexInputs, sizeof(VertexInputs));

    vertexStride = sizeof(Vertex);
    vertices.clear();
    vertices.resize(numVertices * vertexStride);
    memcpy(vertices.data(), newVertices.data(), numVertices * vertexStride);
}

void Mesh::CreateInputElements(const D3DVERTEXELEMENT9* declaration)
{
    map<BYTE, LPCSTR> nameMap;
    nameMap[D3DDECLUSAGE_POSITION] = "POSITION";
    nameMap[D3DDECLUSAGE_BLENDWEIGHT] = "BLENDWEIGHT";
    nameMap[D3DDECLUSAGE_BLENDINDICES] = "BLENDINDICES";
    nameMap[D3DDECLUSAGE_NORMAL] = "NORMAL";
    nameMap[D3DDECLUSAGE_TEXCOORD] = "TEXCOORD";
    nameMap[D3DDECLUSAGE_TANGENT] = "TANGENT";
    nameMap[D3DDECLUSAGE_BINORMAL] = "BITANGENT";
    nameMap[D3DDECLUSAGE_COLOR] = "COLOR";

    map<BYTE, DXGI_FORMAT> formatMap;
    formatMap[D3DDECLTYPE_FLOAT1] = DXGI_FORMAT_R32_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT2] = DXGI_FORMAT_R32G32_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT3] = DXGI_FORMAT_R32G32B32_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT4] = DXGI_FORMAT_R32G32B32A32_FLOAT;
    formatMap[D3DDECLTYPE_D3DCOLOR] = DXGI_FORMAT_R8G8B8A8_UNORM;
    formatMap[D3DDECLTYPE_UBYTE4] = DXGI_FORMAT_R8G8B8A8_UINT;
    formatMap[D3DDECLTYPE_SHORT2] = DXGI_FORMAT_R16G16_SINT;
    formatMap[D3DDECLTYPE_SHORT4] = DXGI_FORMAT_R16G16B16A16_SINT;
    formatMap[D3DDECLTYPE_UBYTE4N] = DXGI_FORMAT_R8G8B8A8_UNORM;
    formatMap[D3DDECLTYPE_SHORT2N] = DXGI_FORMAT_R16G16_SNORM;
    formatMap[D3DDECLTYPE_SHORT4N] = DXGI_FORMAT_R16G16B16A16_SNORM;
    formatMap[D3DDECLTYPE_USHORT2N] = DXGI_FORMAT_R16G16_UNORM;
    formatMap[D3DDECLTYPE_USHORT4N] = DXGI_FORMAT_R16G16B16A16_UNORM;
    formatMap[D3DDECLTYPE_UDEC3] = DXGI_FORMAT_R10G10B10A2_UINT;
    formatMap[D3DDECLTYPE_DEC3N] = DXGI_FORMAT_R10G10B10A2_UNORM;
    formatMap[D3DDECLTYPE_FLOAT16_2] = DXGI_FORMAT_R16G16_FLOAT;
    formatMap[D3DDECLTYPE_FLOAT16_4] = DXGI_FORMAT_R16G16B16A16_FLOAT;

    // Figure out the number of elements
    uint32 numInputElements = 0;
    while(declaration[numInputElements].Stream != 0xFF)
    {
        const D3DVERTEXELEMENT9& element9 = declaration[numInputElements];
        D3D11_INPUT_ELEMENT_DESC element11;
        element11.InputSlot = 0;
        element11.InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA;
        element11.InstanceDataStepRate = 0;
        element11.SemanticName = nameMap[element9.Usage];
        element11.Format = formatMap[element9.Type];
        element11.AlignedByteOffset = element9.Offset;
        element11.SemanticIndex = element9.UsageIndex;
        inputElements.push_back(element11);

        numInputElements++;
    }
}

void Mesh::CreateVertexAndIndexBuffers(ID3D11Device* device)
{
    Assert_(numVertices > 0);
    Assert_(numIndices > 0);

    D3D11_BUFFER_DESC bufferDesc;
    bufferDesc.Usage = D3D11_USAGE_IMMUTABLE;
    bufferDesc.ByteWidth = vertexStride * numVertices;
    bufferDesc.BindFlags = D3D11_BIND_VERTEX_BUFFER;
    bufferDesc.CPUAccessFlags = 0;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    D3D11_SUBRESOURCE_DATA initData;
    initData.pSysMem = vertices.data();
    initData.SysMemPitch = 0;
    initData.SysMemSlicePitch = 0;
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &vertexBuffer));

    bufferDesc.ByteWidth = IndexSize() * numIndices;
    bufferDesc.BindFlags = D3D11_BIND_INDEX_BUFFER;
    bufferDesc.MiscFlags = 0;
    bufferDesc.StructureByteStride = 0;

    initData.pSysMem = indices.data();
    DXCall(device->CreateBuffer(&bufferDesc, &initData, &indexBuffer));
}

// Does a basic draw of all parts
void Mesh::Render(ID3D11DeviceContext* context)
{
    // Set the vertices and indices
    ID3D11Buffer* vertexBuffers[1] = { vertexBuffer };
    uint32 vertexStrides[1] = { vertexStride };
    uint32 offsets[1] = { 0 };
    context->IASetVertexBuffers(0, 1, vertexBuffers, vertexStrides, offsets);
    context->IASetIndexBuffer(indexBuffer, IndexBufferFormat(), 0);
    context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

    // Draw each MeshPart
    for(size_t i = 0; i < meshParts.size(); ++i)
    {
        MeshPart& meshPart = meshParts[i];
        context->DrawIndexed(meshPart.IndexCount, meshPart.IndexStart, 0);
    }
}

// == Model =======================================================================================

void Model::CreateFromSDKMeshFile(ID3D11Device* device, LPCWSTR fileName, const wchar* normalMapSuffix,
                                  bool generateTangentFrame, bool overrideNormalMaps, bool forceSRGB)
{
    Assert_(FileExists(fileName));

    // Use the SDKMesh class to load in the data
    SDKMesh sdkMesh;
    sdkMesh.Create(fileName);

    fileDirectory = GetDirectoryFromFilePath(fileName);

    // Make materials
    uint32 numMaterials = sdkMesh.GetNumMaterials();
    for(uint32 i = 0; i < numMaterials; ++i)
    {
        MeshMaterial material;
        SDKMESH_MATERIAL* mat = sdkMesh.GetMaterial(i);
        material.DiffuseMapName = AnsiToWString(mat->DiffuseTexture);
        material.NormalMapName = AnsiToWString(mat->NormalTexture);

        // Add the normal map prefix
        if (normalMapSuffix && material.DiffuseMapName.length() > 0
                && (material.NormalMapName.length() == 0 || overrideNormalMaps))
        {
            wstring base = GetFilePathWithoutExtension(material.DiffuseMapName.c_str());
            wstring extension = GetFileExtension(material.DiffuseMapName.c_str());
            material.NormalMapName = base + normalMapSuffix + L"." + extension;
        }

        LoadMaterialResources(material, fileDirectory, device, forceSRGB);

        meshMaterials.push_back(material);
    }

    uint32 numMeshes = sdkMesh.GetNumMeshes();
    meshes.resize(numMeshes);
    for(uint32 meshIdx = 0; meshIdx < numMeshes; ++meshIdx)
        meshes[meshIdx].InitFromSDKMesh(device, sdkMesh, meshIdx, generateTangentFrame);
}

void Model::CreateWithAssimp(ID3D11Device* device, const wchar* fileName, bool forceSRGB)
{
    Assert_(FileExists(fileName));

    std::string fileNameAnsi = WStringToAnsi(fileName);

    Assimp::Importer importer;
    uint32 flags = aiProcess_CalcTangentSpace |
                   aiProcess_Triangulate |
                   aiProcess_JoinIdenticalVertices |
                   aiProcess_MakeLeftHanded |
                   aiProcess_PreTransformVertices |
                   aiProcess_RemoveRedundantMaterials |
                   aiProcess_OptimizeMeshes |
                   aiProcess_FlipUVs |
                   aiProcess_FlipWindingOrder ;
    const aiScene* scene = importer.ReadFile(fileNameAnsi, flags);

    if(scene == nullptr)
        throw Exception(L"Failed to load scene " + std::wstring(fileName) +
                        L": " + AnsiToWString(importer.GetErrorString()));

    if(scene->mNumMeshes == 0)
        throw Exception(L"Scene " + std::wstring(fileName) + L" has no meshes");

    if(scene->mNumMaterials == 0)
        throw Exception(L"Scene " + std::wstring(fileName) + L" has no materials");

    fileDirectory = GetDirectoryFromFilePath(fileName);

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

void Model::CreateFromMeshData(ID3D11Device* device, const wchar* fileName, bool forceSRGB)
{
    FileReadSerializer serializer(fileName);
    Serialize(serializer, device, forceSRGB);
}

void Model::GenerateBoxScene(ID3D11Device* device, const Float3& dimensions, const Float3& position,
                             const Quaternion& orientation, const wchar* colorMap,
                             const wchar* normalMap)
{
    MeshMaterial material;
    material.DiffuseMapName = colorMap;
    material.NormalMapName = normalMap;
    fileDirectory = L"..\\Content\\Textures\\";
    LoadMaterialResources(material, L"..\\Content\\Textures\\", device, false);
    meshMaterials.push_back(material);

    meshes.resize(1);
    meshes[0].InitBox(device, dimensions, position, orientation, 0);
}

void Model::GenerateBoxTestScene(ID3D11Device* device)
{
    MeshMaterial material;
    material.DiffuseMapName = L"White.png";
    material.NormalMapName = L"Hex.png";
    fileDirectory = L"..\\Content\\Textures\\";
    LoadMaterialResources(material, L"..\\Content\\Textures\\", device, false);
    meshMaterials.push_back(material);

    meshes.resize(2);
    meshes[0].InitBox(device, Float3(2.0f), Float3(0.0f, 1.5f, 0.0f), Quaternion(), 0);
    meshes[1].InitBox(device, Float3(10.0f, 0.25f, 10.0f), Float3(0.0f), Quaternion(), 0);
}


void Model::GeneratePlaneScene(ID3D11Device* device, const Float2& dimensions, const Float3& position,
                               const Quaternion& orientation, const wchar* colorMap,
                               const wchar* normalMap)
{
    MeshMaterial material;
    material.DiffuseMapName = colorMap;
    material.NormalMapName = normalMap;
    fileDirectory = L"..\\Content\\Textures\\";
    LoadMaterialResources(material, L"..\\Content\\Textures\\", device, false);
    meshMaterials.push_back(material);

    meshes.resize(1);
    meshes[0].InitPlane(device, dimensions, position, orientation, 0);
}

void Model::GenerateCorneaScene(ID3D11Device* device)
{
    MeshMaterial material;
    material.DiffuseMapName = L"Eyeball.png";
    material.NormalMapName = L"";
    fileDirectory = L"..\\Content\\Textures\\";
    LoadMaterialResources(material, L"..\\Content\\Textures\\", device, false);
    meshMaterials.push_back(material);

    meshes.resize(1);
    meshes[0].InitCornea(device, 0);
}

void Model::LoadMaterialResources(MeshMaterial& material, const wstring& directory, ID3D11Device* device, bool forceSRGB)
{
    // Load the diffuse map
    wstring diffuseMapPath = directory + material.DiffuseMapName;
    if(material.DiffuseMapName.length() > 1 && FileExists(diffuseMapPath.c_str()))
        material.DiffuseMap = LoadTexture(device, diffuseMapPath.c_str(), forceSRGB);
    else
    {
        static ID3D11ShaderResourceViewPtr defaultDiffuse;
        if(defaultDiffuse == nullptr)
            defaultDiffuse = LoadTexture(device, L"..\\Content\\Textures\\Default.dds");
        material.DiffuseMap = defaultDiffuse;
    }

    // Load the normal map
    wstring normalMapPath = directory + material.NormalMapName;
    if(material.NormalMapName.length() > 1 && FileExists(normalMapPath.c_str()))
        material.NormalMap = LoadTexture(device, normalMapPath.c_str());
    else
    {
        static ID3D11ShaderResourceViewPtr defaultNormalMap;
        if(defaultNormalMap == nullptr)
            defaultNormalMap = LoadTexture(device, L"..\\Content\\Textures\\DefaultNormalMap.dds");
        material.NormalMap = defaultNormalMap;
    }

     // Load the roughness map
    wstring roughnessMapPath = directory + material.RoughnessMapName;
    if(material.RoughnessMapName.length() > 1 && FileExists(roughnessMapPath.c_str()))
        material.RoughnessMap = LoadTexture(device, roughnessMapPath.c_str());
    else
    {
        static ID3D11ShaderResourceViewPtr defaultRoughnessMap;
        if(defaultRoughnessMap == nullptr)
            defaultRoughnessMap = LoadTexture(device, L"..\\Content\\Textures\\DefaultRoughness.dds");
        material.RoughnessMap = defaultRoughnessMap;
    }

     // Load the metallic map
    wstring metallicMapPath = directory + material.MetallicMapName;
    if(material.MetallicMapName.length() > 1 && FileExists(metallicMapPath.c_str()))
        material.MetallicMap = LoadTexture(device, metallicMapPath.c_str());
    else
    {
        static ID3D11ShaderResourceViewPtr defaultMetallicMap;
        if(defaultMetallicMap == nullptr)
            defaultMetallicMap = LoadTexture(device, L"..\\Content\\Textures\\DefaultBlack.dds");
        material.MetallicMap = defaultMetallicMap;
    }
}

}