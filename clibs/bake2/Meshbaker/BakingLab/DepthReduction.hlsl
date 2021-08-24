//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Includes
//=================================================================================================
#include "SharedConstants.h"

//=================================================================================================
// Constants
//=================================================================================================
static const uint NumThreads = ReductionTGSize * ReductionTGSize;

//=================================================================================================
// Resources
//=================================================================================================
#if MSAA_
    Texture2DMS<float> DepthMap : register(t0);
#else
    Texture2D<float> DepthMap : register(t0);
#endif

Texture2D<float2> ReductionMap : register(t0);

RWTexture2D<unorm float2> OutputMap : register(u0);

cbuffer ReductionConstants : register(b0)
{
    float4x4 Projection;
    float NearClip;
    float FarClip;
    uint2 TextureSize;
    uint NumSamples;
}

// -- shared memory
groupshared float2 depthsamples[NumThreads];

//=================================================================================================
// Depth reduction, intial pass
//=================================================================================================
[numthreads(ReductionTGSize, ReductionTGSize, 1)]
void DepthReductionInitialCS(in uint3 GroupID : SV_GroupID,
                             in uint3 GroupThreadID : SV_GroupThreadID,
                             uint ThreadIndex : SV_GroupIndex)
{
    float minDepth = 1.0f;
    float maxDepth = 0.0f;

    uint2 samplePos = GroupID.xy * ReductionTGSize + GroupThreadID.xy;
    samplePos = min(samplePos, TextureSize - 1);

    #if MSAA_
        for(uint sIdx = 0; sIdx < NumSamples; ++sIdx)
        {
            float depthSample = DepthMap.Load(samplePos, sIdx);

            if(depthSample < 1.0f)
            {
                // Convert to linear Z
                depthSample = Projection._43 / (depthSample - Projection._33);
                depthSample = saturate((depthSample - NearClip) / (FarClip - NearClip));
                minDepth = min(minDepth, depthSample);
                maxDepth = max(maxDepth, depthSample);
            }
        }
    #else
        float depthSample = DepthMap[samplePos];

        if(depthSample < 1.0f)
        {
            // Convert to linear Z
            depthSample = Projection._43 / (depthSample - Projection._33);
            depthSample = saturate((depthSample - NearClip) / (FarClip - NearClip));
            minDepth = min(minDepth, depthSample);
            maxDepth = max(maxDepth, depthSample);
        }
    #endif

    // Store in shared memory
    depthsamples[ThreadIndex] = float2(minDepth, maxDepth);
    GroupMemoryBarrierWithGroupSync();

    // Reduce
    [unroll]
    for(uint s = NumThreads / 2; s > 0; s >>= 1)
    {
        if(ThreadIndex < s)
        {
            depthsamples[ThreadIndex].x = min(depthsamples[ThreadIndex].x, depthsamples[ThreadIndex + s].x);
            depthsamples[ThreadIndex].y = max(depthsamples[ThreadIndex].y, depthsamples[ThreadIndex + s].y);
        }

        GroupMemoryBarrierWithGroupSync();
    }

    if(ThreadIndex == 0)
    {
        minDepth = depthsamples[0].x;
        maxDepth = depthsamples[0].y;
        OutputMap[GroupID.xy] = float2(minDepth, maxDepth);
    }
}

//=================================================================================================
// Depth reduction, 2nd pass onwards
//=================================================================================================
[numthreads(ReductionTGSize, ReductionTGSize, 1)]
void DepthReductionCS(in uint3 GroupID : SV_GroupID, in uint3 GroupThreadID : SV_GroupThreadID,
                      in uint ThreadIndex : SV_GroupIndex)
{
    uint2 samplePos = GroupID.xy * ReductionTGSize + GroupThreadID.xy;
    samplePos = min(samplePos, TextureSize - 1);

    float minDepth = ReductionMap[samplePos].x;
    float maxDepth = ReductionMap[samplePos].y;


    // Store in shared memory
    depthsamples[ThreadIndex] = float2(minDepth, maxDepth);
    GroupMemoryBarrierWithGroupSync();

    // Reduce
    [unroll]
    for(uint s = NumThreads / 2; s > 0; s >>= 1)
    {
        if(ThreadIndex < s)
        {
            depthsamples[ThreadIndex].x = min(depthsamples[ThreadIndex].x, depthsamples[ThreadIndex + s].x);
            depthsamples[ThreadIndex].y = max(depthsamples[ThreadIndex].y, depthsamples[ThreadIndex + s].y);
        }

        GroupMemoryBarrierWithGroupSync();
    }

    if(ThreadIndex == 0)
    {
        minDepth = depthsamples[0].x;
        maxDepth = depthsamples[0].y;
        OutputMap[GroupID.xy] = float2(minDepth, maxDepth);
    }
}