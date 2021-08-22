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
#include "AppSettings.hlsl"

//=================================================================================================
// Constants
//=================================================================================================
static const uint NumThreads = TGSize_ * TGSize_;

//=================================================================================================
// Resources
//=================================================================================================
Texture2D<float4> InputMap : register(t0);
RWTexture2D<float> OutputMap : register(u0);

// -- shared memory
groupshared float Samples[NumThreads];

//=================================================================================================
// Computes a downscaled mask for the near field
//=================================================================================================
[numthreads(TGSize_, TGSize_, 1)]
void ComputeNearMask(in uint3 GroupID : SV_GroupID, in uint3 GroupThreadID : SV_GroupThreadID,
                    in uint ThreadIndex : SV_GroupIndex)
{
    uint2 textureSize;
    InputMap.GetDimensions(textureSize.x, textureSize.y);

    uint2 samplePos = GroupID.xy * TGSize_ + GroupThreadID.xy;
    samplePos = min(samplePos, textureSize - 1);

    float cocSample = InputMap[samplePos].w;

    // -- store in shared memory
    Samples[ThreadIndex] = cocSample;
    GroupMemoryBarrierWithGroupSync();

    // -- reduce
	[unroll]
	for(uint s = NumThreads / 2; s > 0; s >>= 1)
    {
		if(ThreadIndex < s)
			Samples[ThreadIndex] = max(Samples[ThreadIndex], Samples[ThreadIndex + s]);

		GroupMemoryBarrierWithGroupSync();
	}

    if(ThreadIndex == 0)
        OutputMap[GroupID.xy] = Samples[0];
}