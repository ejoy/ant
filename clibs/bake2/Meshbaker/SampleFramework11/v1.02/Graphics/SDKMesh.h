//--------------------------------------------------------------------------------------
// File: SDKMesh.h
//
// Disclaimer:
//   The SDK Mesh format (.sdkmesh) is not a recommended file format for shipping titles.
//   It was designed to meet the specific needs of the SDK samples.  Any real-world
//   applications should avoid this file format in favor of a destination format that
//   meets the specific needs of the application.
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------
#pragma once
#ifndef _SDKMESH_
#define _SDKMESH_

#include "..\\SF11_Math.h"

namespace SampleFramework11
{

//--------------------------------------------------------------------------------------
// Hard Defines for the various structures
//--------------------------------------------------------------------------------------
#define SDKMESH_FILE_VERSION 101
#define MAX_VERTEX_ELEMENTS 32
#define MAX_VERTEX_STREAMS 16
#define MAX_FRAME_NAME 100
#define MAX_MESH_NAME 100
#define MAX_SUBSET_NAME 100
#define MAX_MATERIAL_NAME 100
#define MAX_TEXTURE_NAME MAX_PATH
#define MAX_MATERIAL_PATH MAX_PATH
#define INVALID_FRAME ((UINT)-1)
#define INVALID_MESH ((UINT)-1)
#define INVALID_MATERIAL ((UINT)-1)
#define INVALID_SUBSET ((UINT)-1)
#define INVALID_ANIMATION_DATA ((UINT)-1)
#define INVALID_SAMPLER_SLOT ((UINT)-1)
#define ERROR_RESOURCE_VALUE 1

template<typename TYPE> BOOL IsErrorResource( TYPE data )
{
    if( ( TYPE )ERROR_RESOURCE_VALUE == data )
        return true;
    return false;
}
//--------------------------------------------------------------------------------------
// Enumerated Types.  These will have mirrors in both D3D9 and D3D11
//--------------------------------------------------------------------------------------
enum SDKMESH_PRIMITIVE_TYPE
{
    PT_TRIANGLE_LIST = 0,
    PT_TRIANGLE_STRIP,
    PT_LINE_LIST,
    PT_LINE_STRIP,
    PT_POINT_LIST,
    PT_TRIANGLE_LIST_ADJ,
    PT_TRIANGLE_STRIP_ADJ,
    PT_LINE_LIST_ADJ,
    PT_LINE_STRIP_ADJ,
    PT_QUAD_PATCH_LIST,
    PT_TRIANGLE_PATCH_LIST,
};

enum SDKMESH_INDEX_TYPE
{
    IT_16BIT = 0,
    IT_32BIT,
};

enum FRAME_TRANSFORM_TYPE
{
    FTT_RELATIVE = 0,
    FTT_ABSOLUTE,    //This is not currently used but is here to support absolute transformations in the future
};

//--------------------------------------------------------------------------------------
// Structures.  Unions with pointers are forced to 64bit.
//--------------------------------------------------------------------------------------
struct SDKMESH_HEADER
{
    //Basic Info and sizes
    UINT Version;
    BYTE IsBigEndian;
    uint64 HeaderSize;
    uint64 NonBufferDataSize;
    uint64 BufferDataSize;

    //Stats
    UINT NumVertexBuffers;
    UINT NumIndexBuffers;
    UINT NumMeshes;
    UINT NumTotalSubsets;
    UINT NumFrames;
    UINT NumMaterials;

    //Offsets to Data
    uint64 VertexStreamHeadersOffset;
    uint64 IndexStreamHeadersOffset;
    uint64 MeshDataOffset;
    uint64 SubsetDataOffset;
    uint64 FrameDataOffset;
    uint64 MaterialDataOffset;
};

struct SDKMESH_VERTEX_BUFFER_HEADER
{
    uint64 NumVertices;
    uint64 SizeBytes;
    uint64 StrideBytes;
    D3DVERTEXELEMENT9 Decl[MAX_VERTEX_ELEMENTS];
    union
    {
        uint64 DataOffset;        //(This also forces the union to 64bits)
        ID3D11Buffer* pVB11;
    };
};

struct SDKMESH_INDEX_BUFFER_HEADER
{
    uint64 NumIndices;
    uint64 SizeBytes;
    UINT IndexType;
    union
    {
        uint64 DataOffset;        //(This also forces the union to 64bits)
        ID3D11Buffer* pIB11;
    };
};

struct SDKMESH_MESH
{
    char Name[MAX_MESH_NAME];
    BYTE NumVertexBuffers;
    UINT VertexBuffers[MAX_VERTEX_STREAMS];
    UINT IndexBuffer;
    UINT NumSubsets;
    UINT NumFrameInfluences; //aka bones

    Float3 BoundingBoxCenter;
    Float3 BoundingBoxExtents;

    union
    {
        uint64 SubsetOffset;  //Offset to list of subsets (This also forces the union to 64bits)
        UINT* pSubsets;      //Pointer to list of subsets
    };
    union
    {
        uint64 FrameInfluenceOffset;  //Offset to list of frame influences (This also forces the union to 64bits)
        UINT* pFrameInfluences;      //Pointer to list of frame influences
    };
};

struct SDKMESH_SUBSET
{
    char Name[MAX_SUBSET_NAME];
    UINT MaterialID;
    UINT PrimitiveType;
    uint64 IndexStart;
    uint64 IndexCount;
    uint64 VertexStart;
    uint64 VertexCount;
};

struct SDKMESH_FRAME
{
    char Name[MAX_FRAME_NAME];
    UINT Mesh;
    UINT ParentFrame;
    UINT ChildFrame;
    UINT SiblingFrame;
    Float4x4 Matrix;
    UINT AnimationDataIndex;    //Used to index which set of keyframes transforms this frame
};

struct SDKMESH_MATERIAL
{
    char    Name[MAX_MATERIAL_NAME];

    // Use MaterialInstancePath
    char    MaterialInstancePath[MAX_MATERIAL_PATH];

    // Or fall back to d3d8-type materials
    char    DiffuseTexture[MAX_TEXTURE_NAME];
    char    NormalTexture[MAX_TEXTURE_NAME];
    char    SpecularTexture[MAX_TEXTURE_NAME];

    Float4 Diffuse;
    Float4 Ambient;
    Float4 Specular;
    Float4 Emissive;
    FLOAT Power;

    union
    {
        uint64 Force64_1;      //Force the union to 64bits
        IDirect3DTexture9* pDiffuseTexture9;
        ID3D11Texture2D* pDiffuseTexture11;
    };
    union
    {
        uint64 Force64_2;      //Force the union to 64bits
        IDirect3DTexture9* pNormalTexture9;
        ID3D11Texture2D* pNormalTexture11;
    };
    union
    {
        uint64 Force64_3;      //Force the union to 64bits
        IDirect3DTexture9* pSpecularTexture9;
        ID3D11Texture2D* pSpecularTexture11;
    };

    union
    {
        uint64 Force64_4;      //Force the union to 64bits
        ID3D11ShaderResourceView* pDiffuseRV11;
    };
    union
    {
        uint64 Force64_5;        //Force the union to 64bits
        ID3D11ShaderResourceView* pNormalRV11;
    };
    union
    {
        uint64 Force64_6;      //Force the union to 64bits
        ID3D11ShaderResourceView* pSpecularRV11;
    };

};

struct SDKANIMATION_FILE_HEADER
{
    UINT Version;
    BYTE IsBigEndian;
    UINT FrameTransformType;
    UINT NumFrames;
    UINT NumAnimationKeys;
    UINT AnimationFPS;
    uint64 AnimationDataSize;
    uint64 AnimationDataOffset;
};

struct SDKANIMATION_DATA
{
    Float3 Translation;
    Float4 Orientation;
    Float3 Scaling;
};

struct SDKANIMATION_FRAME_DATA
{
    char FrameName[MAX_FRAME_NAME];
    union
    {
        uint64 DataOffset;
        SDKANIMATION_DATA* pAnimationData;
    };
};

#ifndef _CONVERTER_APP_

//--------------------------------------------------------------------------------------
// CDXUTSDKMesh class.  This class reads the sdkmesh file format for use by the samples
//--------------------------------------------------------------------------------------
class SDKMesh
{
private:
    UINT m_NumOutstandingResources;
    bool m_bLoading;
    //BYTE*                         m_pBufferData;
    HANDLE m_hFile;
    HANDLE m_hFileMappingObject;
    std::vector<BYTE*> m_MappedPointers;

protected:
    //These are the pointers to the two chunks of data loaded in from the mesh file
    BYTE* m_pStaticMeshData;
    BYTE* m_pHeapData;
    BYTE* m_pAnimationData;
    BYTE** m_ppVertices;
    BYTE** m_ppIndices;

    //General mesh info
    SDKMESH_HEADER* m_pMeshHeader;
    SDKMESH_VERTEX_BUFFER_HEADER* m_pVertexBufferArray;
    SDKMESH_INDEX_BUFFER_HEADER* m_pIndexBufferArray;
    SDKMESH_MESH* m_pMeshArray;
    SDKMESH_SUBSET* m_pSubsetArray;
    SDKMESH_FRAME* m_pFrameArray;
    SDKMESH_MATERIAL* m_pMaterialArray;

    // Adjacency information (not part of the m_pStaticMeshData, so it must be created and destroyed separately )
    SDKMESH_INDEX_BUFFER_HEADER* m_pAdjacencyIndexBufferArray;

    //Animation (TODO: Add ability to load/track multiple animation sets)
    SDKANIMATION_FILE_HEADER* m_pAnimationHeader;
    SDKANIMATION_FRAME_DATA* m_pAnimationFrameData;
    Float4x4* m_pBindPoseFrameMatrices;
    Float4x4* m_pTransformedFrameMatrices;
    Float4x4* m_pWorldPoseFrameMatrices;

protected:
    virtual HRESULT                 CreateFromFile( LPCWSTR szFileName,
                                                    bool bCreateAdjacencyIndices);

    virtual HRESULT                 CreateFromMemory( BYTE* pData,
                                                      UINT DataBytes,
                                                      bool bCreateAdjacencyIndices,
                                                      bool bCopyStatic );
public:
                                    SDKMesh();
    virtual                         ~SDKMesh();

    virtual HRESULT                 Create( LPCWSTR szFileName, bool bCreateAdjacencyIndices = false );
    virtual HRESULT                 Create( BYTE* pData, UINT DataBytes,
                                            bool bCreateAdjacencyIndices = false, bool bCopyStatic = false );
    virtual void                    Destroy();


    //Helpers (D3D11 specific)
    static D3D11_PRIMITIVE_TOPOLOGY GetPrimitiveType11( SDKMESH_PRIMITIVE_TYPE PrimType );
    DXGI_FORMAT                     GetIBFormat11( UINT iMesh );
    SDKMESH_INDEX_TYPE              GetIndexType( UINT iMesh );

    //Helpers (general)
    UINT                            GetNumMeshes();
    UINT                            GetNumMaterials();
    UINT                            GetNumVBs();
    UINT                            GetNumIBs();

    BYTE* GetRawVerticesAt( UINT iVB );
    BYTE* GetRawIndicesAt( UINT iIB );
    SDKMESH_MATERIAL* GetMaterial( UINT iMaterial );
    SDKMESH_MESH* GetMesh( UINT iMesh );
    UINT                            GetNumSubsets( UINT iMesh );
    SDKMESH_SUBSET* GetSubset( UINT iMesh, UINT iSubset );
    UINT                            GetVertexStride( UINT iMesh, UINT iVB );
    UINT                            GetNumFrames();
    SDKMESH_FRAME*                  GetFrame( UINT iFrame );
    SDKMESH_FRAME*                  FindFrame( char* pszName );
    uint64                          GetNumVertices( UINT iMesh, UINT iVB );
    uint64                          GetNumIndices( UINT iMesh );

    const D3DVERTEXELEMENT9*        VBElements( UINT iVB ) { return m_pVertexBufferArray[0].Decl; }
};


#endif

}

#endif
