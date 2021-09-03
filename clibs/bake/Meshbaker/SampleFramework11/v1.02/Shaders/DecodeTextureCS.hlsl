//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Resources
//=================================================================================================

// Inputs
Texture2D<float4> InputTexture : register(t0);
Texture2DArray<float4> InputTextureArray : register(t0);

// Outputs
#if UnormOutput_
    RWTexture2D<unorm float4> OutputTexture : register(u0);
    RWTexture2DArray<unorm float4> OutputTextureArray : register(u0);
#else
    RWTexture2D<float4> OutputTexture : register(u0);
    RWTexture2DArray<float4> OutputTextureArray : register(u0);
#endif

//=================================================================================================
// Entry points
//=================================================================================================
[numthreads(TGSize_, TGSize_, 1)]
void DecodeTextureCS(in uint3 GroupID : SV_GroupID, in uint3 GroupThreadID : SV_GroupThreadID)
{
    const uint2 texelIdx = GroupID.xy * uint2(TGSize_, TGSize_) + GroupThreadID.xy;
    OutputTexture[texelIdx] = InputTexture[texelIdx];
}

[numthreads(TGSize_, TGSize_, 1)]
void DecodeTextureArrayCS(in uint3 GroupID : SV_GroupID, in uint3 GroupThreadID : SV_GroupThreadID)
{
    const uint3 texelIdx = uint3(GroupID.xy * uint2(TGSize_, TGSize_) + GroupThreadID.xy, GroupID.z);
    OutputTextureArray[texelIdx] = InputTextureArray[texelIdx];
}