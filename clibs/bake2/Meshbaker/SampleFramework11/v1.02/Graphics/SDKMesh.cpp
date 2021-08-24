//--------------------------------------------------------------------------------------
// File: SDKMesh.cpp
//
// The SDK Mesh format (.sdkmesh) is not a recommended file format for games.
// It was designed to meet the specific needs of the SDK samples.  Any real-world
// applications should avoid this file format in favor of a destination format that
// meets the specific needs of the application.
//
// Copyright (c) Microsoft Corporation. All rights reserved.
//--------------------------------------------------------------------------------------
#include "PCH.h"
#include "SDKMesh.h"
#include "..\\Utility.h"

#ifndef SAFE_DELETE
#define SAFE_DELETE(p)       { if (p) { delete (p);     (p)=NULL; } }
#endif
#ifndef SAFE_DELETE_ARRAY
#define SAFE_DELETE_ARRAY(p) { if (p) { delete[] (p);   (p)=NULL; } }
#endif
#ifndef SAFE_RELEASE
#define SAFE_RELEASE(p)      { if (p) { (p)->Release(); (p)=NULL; } }
#endif

namespace SampleFramework11
{


//--------------------------------------------------------------------------------------
HRESULT SDKMesh::CreateFromFile( LPCWSTR szFileName,
                                      bool bCreateAdjacencyIndices)
{
    HRESULT hr = S_OK;

    // Open the file
    m_hFile = CreateFile( szFileName, FILE_READ_DATA, FILE_SHARE_READ, NULL, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN,
                          NULL );
    if( INVALID_HANDLE_VALUE == m_hFile )
        return E_FAIL;

    // Get the file size
    LARGE_INTEGER FileSize;
    GetFileSizeEx( m_hFile, &FileSize );
    UINT cBytes = FileSize.LowPart;

    // Allocate memory
    m_pStaticMeshData = new BYTE[ cBytes ];
    if( !m_pStaticMeshData )
    {
        CloseHandle( m_hFile );
        return E_OUTOFMEMORY;
    }

    // Read in the file
    DWORD dwBytesRead;
    if( !ReadFile( m_hFile, m_pStaticMeshData, cBytes, &dwBytesRead, NULL ) )
        hr = E_FAIL;

    CloseHandle( m_hFile );

    if( SUCCEEDED( hr ) )
    {
        hr = CreateFromMemory( m_pStaticMeshData,
                               cBytes,
                               bCreateAdjacencyIndices,
                               false);
        if( FAILED( hr ) )
            delete []m_pStaticMeshData;
    }

    return hr;
}

HRESULT SDKMesh::CreateFromMemory( BYTE* pData,
                                        UINT DataBytes,
                                        bool bCreateAdjacencyIndices,
                                        bool bCopyStatic )
{
    HRESULT hr = E_FAIL;
    Float3 lower;
    Float3 upper;


    // Set outstanding resources to zero
    m_NumOutstandingResources = 0;

    if( bCopyStatic )
    {
        SDKMESH_HEADER* pHeader = ( SDKMESH_HEADER* )pData;

        SIZE_T StaticSize = ( SIZE_T )( pHeader->HeaderSize + pHeader->NonBufferDataSize );
        m_pHeapData = new BYTE[ StaticSize ];
        if( !m_pHeapData )
            return hr;

        m_pStaticMeshData = m_pHeapData;

        CopyMemory( m_pStaticMeshData, pData, StaticSize );
    }
    else
    {
        m_pHeapData = pData;
        m_pStaticMeshData = pData;
    }

    // Pointer fixup
    m_pMeshHeader = ( SDKMESH_HEADER* )m_pStaticMeshData;
    m_pVertexBufferArray = ( SDKMESH_VERTEX_BUFFER_HEADER* )( m_pStaticMeshData +
                                                              m_pMeshHeader->VertexStreamHeadersOffset );
    m_pIndexBufferArray = ( SDKMESH_INDEX_BUFFER_HEADER* )( m_pStaticMeshData +
                                                            m_pMeshHeader->IndexStreamHeadersOffset );
    m_pMeshArray = ( SDKMESH_MESH* )( m_pStaticMeshData + m_pMeshHeader->MeshDataOffset );
    m_pSubsetArray = ( SDKMESH_SUBSET* )( m_pStaticMeshData + m_pMeshHeader->SubsetDataOffset );
    m_pFrameArray = ( SDKMESH_FRAME* )( m_pStaticMeshData + m_pMeshHeader->FrameDataOffset );
    m_pMaterialArray = ( SDKMESH_MATERIAL* )( m_pStaticMeshData + m_pMeshHeader->MaterialDataOffset );

    // Setup subsets
    for( UINT i = 0; i < m_pMeshHeader->NumMeshes; i++ )
    {
        m_pMeshArray[i].pSubsets = ( UINT* )( m_pStaticMeshData + m_pMeshArray[i].SubsetOffset );
        m_pMeshArray[i].pFrameInfluences = ( UINT* )( m_pStaticMeshData + m_pMeshArray[i].FrameInfluenceOffset );
    }

    // error condition
    if( m_pMeshHeader->Version != SDKMESH_FILE_VERSION )
    {
        return E_NOINTERFACE;
    }

    // Setup buffer data pointer
    BYTE* pBufferData = pData + m_pMeshHeader->HeaderSize + m_pMeshHeader->NonBufferDataSize;

    // Get the start of the buffer data
    uint64 BufferDataStart = m_pMeshHeader->HeaderSize + m_pMeshHeader->NonBufferDataSize;

    // Create VBs
    m_ppVertices = new BYTE*[m_pMeshHeader->NumVertexBuffers];
    for( UINT i = 0; i < m_pMeshHeader->NumVertexBuffers; i++ )
    {
        BYTE* pVertices = NULL;
        pVertices = ( BYTE* )( pBufferData + ( m_pVertexBufferArray[i].DataOffset - BufferDataStart ) );

        m_ppVertices[i] = pVertices;
    }

    // Create IBs
    m_ppIndices = new BYTE*[m_pMeshHeader->NumIndexBuffers];
    for( UINT i = 0; i < m_pMeshHeader->NumIndexBuffers; i++ )
    {
        BYTE* pIndices = NULL;
        pIndices = ( BYTE* )( pBufferData + ( m_pIndexBufferArray[i].DataOffset - BufferDataStart ) );

        m_ppIndices[i] = pIndices;
    }

    return S_OK;
}

#define MAX_D3D11_VERTEX_STREAMS D3D11_IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT


//--------------------------------------------------------------------------------------

//--------------------------------------------------------------------------------------
SDKMesh::SDKMesh() : m_NumOutstandingResources( 0 ),
                               m_bLoading( false ),
                               m_hFile( 0 ),
                               m_hFileMappingObject( 0 ),
                               m_pMeshHeader( NULL ),
                               m_pStaticMeshData( NULL ),
                               m_pHeapData( NULL ),
                               m_pAdjacencyIndexBufferArray( NULL ),
                               m_pAnimationData( NULL ),
                               m_pAnimationHeader( NULL ),
                               m_ppVertices( NULL ),
                               m_ppIndices( NULL ),
                               m_pBindPoseFrameMatrices( NULL ),
                               m_pTransformedFrameMatrices( NULL ),
                               m_pWorldPoseFrameMatrices( NULL )
{
}


//--------------------------------------------------------------------------------------
SDKMesh::~SDKMesh()
{
    Destroy();
}

//--------------------------------------------------------------------------------------
HRESULT SDKMesh::Create( LPCTSTR szFileName, bool bCreateAdjacencyIndices )
{
    return CreateFromFile( szFileName, bCreateAdjacencyIndices );
}

//--------------------------------------------------------------------------------------
HRESULT SDKMesh::Create( BYTE* pData, UINT DataBytes, bool bCreateAdjacencyIndices,
                              bool bCopyStatic)
{
    return CreateFromMemory( pData, DataBytes, bCreateAdjacencyIndices, bCopyStatic );
}

//--------------------------------------------------------------------------------------
void SDKMesh::Destroy()
{

    SAFE_DELETE_ARRAY( m_pAdjacencyIndexBufferArray );

    SAFE_DELETE_ARRAY( m_pHeapData );
    m_pStaticMeshData = NULL;
    SAFE_DELETE_ARRAY( m_pAnimationData );
    SAFE_DELETE_ARRAY( m_pBindPoseFrameMatrices );
    SAFE_DELETE_ARRAY( m_pTransformedFrameMatrices );
    SAFE_DELETE_ARRAY( m_pWorldPoseFrameMatrices );

    SAFE_DELETE_ARRAY( m_ppVertices );
    SAFE_DELETE_ARRAY( m_ppIndices );

    m_pMeshHeader = NULL;
    m_pVertexBufferArray = NULL;
    m_pIndexBufferArray = NULL;
    m_pMeshArray = NULL;
    m_pSubsetArray = NULL;
    m_pFrameArray = NULL;
    m_pMaterialArray = NULL;

    m_pAnimationHeader = NULL;
    m_pAnimationFrameData = NULL;

}


//--------------------------------------------------------------------------------------
D3D11_PRIMITIVE_TOPOLOGY SDKMesh::GetPrimitiveType11( SDKMESH_PRIMITIVE_TYPE PrimType )
{
    D3D11_PRIMITIVE_TOPOLOGY retType = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;

    switch( PrimType )
    {
        case PT_TRIANGLE_LIST:
            retType = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;
            break;
        case PT_TRIANGLE_STRIP:
            retType = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP;
            break;
        case PT_LINE_LIST:
            retType = D3D11_PRIMITIVE_TOPOLOGY_LINELIST;
            break;
        case PT_LINE_STRIP:
            retType = D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP;
            break;
        case PT_POINT_LIST:
            retType = D3D11_PRIMITIVE_TOPOLOGY_POINTLIST;
            break;
        case PT_TRIANGLE_LIST_ADJ:
            retType = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST_ADJ;
            break;
        case PT_TRIANGLE_STRIP_ADJ:
            retType = D3D11_PRIMITIVE_TOPOLOGY_TRIANGLESTRIP_ADJ;
            break;
        case PT_LINE_LIST_ADJ:
            retType = D3D11_PRIMITIVE_TOPOLOGY_LINELIST_ADJ;
            break;
        case PT_LINE_STRIP_ADJ:
            retType = D3D11_PRIMITIVE_TOPOLOGY_LINESTRIP_ADJ;
            break;
    };

    return retType;
}

//--------------------------------------------------------------------------------------
DXGI_FORMAT SDKMesh::GetIBFormat11( UINT iMesh )
{
    switch( m_pIndexBufferArray[ m_pMeshArray[ iMesh ].IndexBuffer ].IndexType )
    {
        case IT_16BIT:
            return DXGI_FORMAT_R16_UINT;
        case IT_32BIT:
            return DXGI_FORMAT_R32_UINT;
    };
    return DXGI_FORMAT_R16_UINT;
}

//--------------------------------------------------------------------------------------
UINT SDKMesh::GetNumMeshes()
{
    if( !m_pMeshHeader )
        return 0;
    return m_pMeshHeader->NumMeshes;
}

//--------------------------------------------------------------------------------------
UINT SDKMesh::GetNumMaterials()
{
    if( !m_pMeshHeader )
        return 0;
    return m_pMeshHeader->NumMaterials;
}

//--------------------------------------------------------------------------------------
UINT SDKMesh::GetNumVBs()
{
    if( !m_pMeshHeader )
        return 0;
    return m_pMeshHeader->NumVertexBuffers;
}

//--------------------------------------------------------------------------------------
UINT SDKMesh::GetNumIBs()
{
    if( !m_pMeshHeader )
        return 0;
    return m_pMeshHeader->NumIndexBuffers;
}

//--------------------------------------------------------------------------------------
BYTE* SDKMesh::GetRawVerticesAt( UINT iVB )
{
    return m_ppVertices[iVB];
}

//--------------------------------------------------------------------------------------
BYTE* SDKMesh::GetRawIndicesAt( UINT iIB )
{
    return m_ppIndices[iIB];
}

//--------------------------------------------------------------------------------------
SDKMESH_MATERIAL* SDKMesh::GetMaterial( UINT iMaterial )
{
    return &m_pMaterialArray[ iMaterial ];
}

//--------------------------------------------------------------------------------------
SDKMESH_MESH* SDKMesh::GetMesh( UINT iMesh )
{
    return &m_pMeshArray[ iMesh ];
}

//--------------------------------------------------------------------------------------
UINT SDKMesh::GetNumSubsets( UINT iMesh )
{
    return m_pMeshArray[ iMesh ].NumSubsets;
}

//--------------------------------------------------------------------------------------
SDKMESH_SUBSET* SDKMesh::GetSubset( UINT iMesh, UINT iSubset )
{
    return &m_pSubsetArray[ m_pMeshArray[ iMesh ].pSubsets[iSubset] ];
}

//--------------------------------------------------------------------------------------
UINT SDKMesh::GetVertexStride( UINT iMesh, UINT iVB )
{
    return ( UINT )m_pVertexBufferArray[ m_pMeshArray[ iMesh ].VertexBuffers[iVB] ].StrideBytes;
}

//--------------------------------------------------------------------------------------
uint64 SDKMesh::GetNumVertices( UINT iMesh, UINT iVB )
{
    return m_pVertexBufferArray[ m_pMeshArray[ iMesh ].VertexBuffers[iVB] ].NumVertices;
}

//--------------------------------------------------------------------------------------
uint64 SDKMesh::GetNumIndices( UINT iMesh )
{
    return m_pIndexBufferArray[ m_pMeshArray[ iMesh ].IndexBuffer ].NumIndices;
}

SDKMESH_INDEX_TYPE SDKMesh::GetIndexType( UINT iMesh )
{
    return ( SDKMESH_INDEX_TYPE ) m_pIndexBufferArray[m_pMeshArray[ iMesh ].IndexBuffer].IndexType;
}

}