//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#if _WINDOWS

#pragma once

typedef SampleFramework11::Float2 float2;
typedef SampleFramework11::Float3 float3;
typedef SampleFramework11::Float4 float4;

typedef uint32 uint;
typedef SampleFramework11::Uint2 uint2;
typedef SampleFramework11::Uint3 uint3;
typedef SampleFramework11::Uint4 uint4;

#endif

static const uint ReductionTGSize = 16;

// Info about a single point on the light map that needs to be baked
struct BakePoint
{
    float3 Position;
    float3 Normal;
    float3 Tangent;
    float3 Bitangent;
    float2 Size;
    uint Coverage;
    uint2 TexelPos;

    #if _WINDOWS
        BakePoint() : Coverage(0) {}
    #endif
};