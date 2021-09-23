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
            defaultDiffuse = LoadTexture(device, (ContentDir() + L"Textures\\Default.dds").c_str());
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
            defaultNormalMap = LoadTexture(device, (ContentDir() + L"Textures\\DefaultNormalMap.dds").c_str());
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
            defaultRoughnessMap = LoadTexture(device, (ContentDir() + L"Textures\\DefaultRoughness.dds").c_str());
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
            defaultMetallicMap = LoadTexture(device, (ContentDir() + L"Textures\\DefaultBlack.dds").c_str());
        material.MetallicMap = defaultMetallicMap;
    }
}

}