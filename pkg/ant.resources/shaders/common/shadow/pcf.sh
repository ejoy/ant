#ifndef __SHADOW_FILTERING_PCF__
#define __SHADOW_FILTERING_PCF__

#include "common/shadow/define.sh"

#define u_pcf_kernelsize		u_shadow_filter_param.x

#ifndef USE_SHADOW_COMPARE
#error "PCF4x4 need shadow2DProj work"
#endif //USE_SHADOW_COMPARE

#ifndef PCF_FILTER_SIZE
#error "need define PCF_FILTER_SIZE"
#endif //PCF_FILTER_SIZE

float sample_shadow_compare_offset(shadow_sampler_type shadowsampler, vec4 shadowcoord, uint cascadeidx, vec2 offset)
{
	const vec4 coord = vec4(shadowcoord.xy + offset, shadowcoord.z, shadowcoord.w);
	return sample_shadow_compare(shadowsampler, coord, cascadeidx);
}

#define PCF_TYPE_FAST_CONVENTIONAL_SHADOW_FILTERING 1
#define PCF_TYPE_FIX4 2
#define PCF_TYPE_SIMPLE 3

#if PCF_TYPE == PCF_TYPE_FAST_CONVENTIONAL_SHADOW_FILTERING

#ifndef ENABLE_TEXTURE_GATHER
#error "Need textureGather support"
#endif //ENABLE_TEXTURE_GATHER

//code from: GPU Pro Fast Conventional Shadow Filtering
#define HFS PCF_FILTER_SIZE/2
#include "common/shadow/fast_pcf_weights.sh"

#if BGFX_SHADER_LANGUAGE_HLSL || BGFX_SHADER_LANGUAGE_METAL
vec4 bgfxTextureGatherCmpOffset0(BgfxSampler2DShadow _sampler, vec2 _coord, float _cmpvalue, ivec2 _offset)
{
	return _sampler.m_texture.GatherCmp(_sampler.m_sampler, _coord, _cmpvalue, _offset);
}

// vec4 bgfxTextureGatherCmpOffset1(BgfxSampler2DShadow _sampler, vec2 _coord, float _cmpvalue, ivec2 _offset)
// {
// 	return _sampler.m_texture.GatherCmpGreen(_sampler.m_sampler, _coord, _cmpvalue, _offset);
// }

// vec4 bgfxTextureGatherCmpOffset2(BgfxSampler2DShadow _sampler, vec2 _coord, float _cmpvalue, ivec2 _offset)
// {
// 	return _sampler.m_texture.GatherCmpBlue(_sampler.m_sampler, _coord, _cmpvalue, _offset);
// }

// vec4 bgfxTextureGatherCmpOffset3(BgfxSampler2DShadow _sampler, vec2 _coord, float _cmpvalue, ivec2 _offset)
// {
// 	return _sampler.m_texture.GatherCmpAlpha(_sampler.m_sampler, _coord, _cmpvalue, _offset);
// }

#define textureGatherCmpOffset(_sampler, _coord, _cmpvalue, _offset, _comp) bgfxTextureGatherCmpOffset ## _comp(_sampler, _coord, _cmpvalue, _offset)

float shadow2DProjOffset(sampler2DShadow shadowsampler, vec4 shadowcoord, ivec2 offset)
{
	return shadowsampler.m_texture.SampleCmpLevelZero(shadowsampler.m_sampler, shadowcoord.xyz, shadowcoord.w, offset);
}

#elif BGFX_SHADER_LANGUAGE_SPIRV

#define shadow2DProjOffset textureProjOffset

#endif //!HLSL/METAL

float total_weight() {
	float w = 0.0;
	for(int row = 0; row < PCF_FILTER_SIZE; ++row )
	{
		for(int col = 0; col < PCF_FILTER_SIZE; ++col )
			w += W[row][col];
	}

	return w;
}

float fastPCF(shadow_sampler_type shadowsampler, vec4 shadowcoord, uint cascadeidx)
{
	vec4 s = vec4_splat(0.0);
	float depthlinear = shadowcoord.z;
	float smsize = 1.0/u_shadowmap_texelsize;
	vec2 stc = ( smsize * shadowcoord.xy ) + vec2( 0.5, 0.5 );
	vec2 tcs = floor( stc );
	vec2 fc = stc - tcs;
	vec2 tc = tcs * u_shadowmap_texelsize;

	const float w = total_weight();
	vec4 v1[HFS + 1];
	vec2 v0[HFS + 1];

	UNROLL
	for(int row = -HFS; row <= HFS; row += 2 )
	{
		UNROLL
		for(int col = -HFS; col <= HFS; col += 2 )
		{
			float fSumOfWeights = W[row+HFS][col+HFS];
			
			if( col > -HFS )
				fSumOfWeights += W[row+HFS][col+HFS-1];
			
			if( col < HFS )
				fSumOfWeights += W[row+HFS][col+HFS+1];
			
			if( row > -HFS )
			{
				fSumOfWeights += W[row+HFS-1][col+HFS];
				
				if( col < HFS )
					fSumOfWeights += W[row+HFS-1][col+HFS+1];
				
				if( col > -HFS )
					fSumOfWeights += W[row+HFS-1][col+HFS-1];
				
			}
			
			if( fSumOfWeights != 0.0 ){
				//v1[(col+HFS)/2] = ( tc.zzzz <= g_txShadowMap.Gather( g_samPoint, tc, ivec2( col, row ) ) ) ? (1.0).xxxx : (0.0).xxxx; 
				//use GatherComp for hlsl
				// vec4 value = textureGatherOffset(shadowsampler, tc.xy, ivec2(col, row), 0);
				// v1[(col+HFS)/2] = vec4_splat(depthlinear) <= value ? vec4_splat(1.0) : vec4_splat(0.0)
				v1[(col+HFS)/2] = textureGatherCmpOffset(shadowsampler, tc, depthlinear, ivec2(col, row), 0);
			} else {
				v1[(col+HFS)/2] = vec4_splat(0.0);
			}
				
			
			if( col == -HFS )
			{
				s.x += ( 1 - fc.y ) * ( v1[0].w * ( W[row+HFS][col+HFS] - W[row+HFS][col+HFS] * fc.x ) + 
										v1[0].z * ( fc.x * ( W[row+HFS][col+HFS] - W[row+HFS][col+HFS+1] ) +  W[row+HFS][col+HFS+1] ) );
				s.y += (     fc.y ) * ( v1[0].x * ( W[row+HFS][col+HFS] - W[row+HFS][col+HFS] * fc.x ) + 
										v1[0].y * ( fc.x * ( W[row+HFS][col+HFS] - W[row+HFS][col+HFS+1] ) +  W[row+HFS][col+HFS+1] ) );
				if( row > -HFS )
				{
					s.z += ( 1 - fc.y ) * ( v0[0].x * ( W[row+HFS-1][col+HFS] - W[row+HFS-1][col+HFS] * fc.x ) + 
											v0[0].y * ( fc.x * ( W[row+HFS-1][col+HFS] - W[row+HFS-1][col+HFS+1] ) +  W[row+HFS-1][col+HFS+1] ) );
					s.w += (     fc.y ) * ( v1[0].w * ( W[row+HFS-1][col+HFS] - W[row+HFS-1][col+HFS] * fc.x ) + 
											v1[0].z * ( fc.x * ( W[row+HFS-1][col+HFS] - W[row+HFS-1][col+HFS+1] ) +  W[row+HFS-1][col+HFS+1] ) );
				}
			}
			else if( col == HFS )
			{
				s.x += ( 1 - fc.y ) * ( v1[HFS].w * ( fc.x * ( W[row+HFS][col+HFS-1] - W[row+HFS][col+HFS] ) + W[row+HFS][col+HFS] ) + 
										v1[HFS].z * fc.x * W[row+HFS][col+HFS] );
				s.y += (     fc.y ) * ( v1[HFS].x * ( fc.x * ( W[row+HFS][col+HFS-1] - W[row+HFS][col+HFS] ) + W[row+HFS][col+HFS] ) + 
										v1[HFS].y * fc.x * W[row+HFS][col+HFS] );
				if( row > -HFS )
				{
					s.z += ( 1 - fc.y ) * ( v0[HFS].x * ( fc.x * ( W[row+HFS-1][col+HFS-1] - W[row+HFS-1][col+HFS] ) + W[row+HFS-1][col+HFS] ) + 
											v0[HFS].y * fc.x * W[row+HFS-1][col+HFS] );
					s.w += (     fc.y ) * ( v1[HFS].w * ( fc.x * ( W[row+HFS-1][col+HFS-1] - W[row+HFS-1][col+HFS] ) + W[row+HFS-1][col+HFS] ) + 
											v1[HFS].z * fc.x * W[row+HFS-1][col+HFS] );
				}
			}
			else
			{
				s.x += ( 1 - fc.y ) * ( v1[(col+HFS)/2].w * ( fc.x * ( W[row+HFS][col+HFS-1] - W[row+HFS][col+HFS+0] ) + W[row+HFS][col+HFS+0] ) +
										v1[(col+HFS)/2].z * ( fc.x * ( W[row+HFS][col+HFS-0] - W[row+HFS][col+HFS+1] ) + W[row+HFS][col+HFS+1] ) );
				s.y += (     fc.y ) * ( v1[(col+HFS)/2].x * ( fc.x * ( W[row+HFS][col+HFS-1] - W[row+HFS][col+HFS+0] ) + W[row+HFS][col+HFS+0] ) +
										v1[(col+HFS)/2].y * ( fc.x * ( W[row+HFS][col+HFS-0] - W[row+HFS][col+HFS+1] ) + W[row+HFS][col+HFS+1] ) );
				if( row > -HFS )
				{
					s.z += ( 1 - fc.y ) * ( v0[(col+HFS)/2].x * ( fc.x * ( W[row+HFS-1][col+HFS-1] - W[row+HFS-1][col+HFS+0] ) + W[row+HFS-1][col+HFS+0] ) +
											v0[(col+HFS)/2].y * ( fc.x * ( W[row+HFS-1][col+HFS-0] - W[row+HFS-1][col+HFS+1] ) + W[row+HFS-1][col+HFS+1] ) );
					s.w += (     fc.y ) * ( v1[(col+HFS)/2].w * ( fc.x * ( W[row+HFS-1][col+HFS-1] - W[row+HFS-1][col+HFS+0] ) + W[row+HFS-1][col+HFS+0] ) +
											v1[(col+HFS)/2].z * ( fc.x * ( W[row+HFS-1][col+HFS-0] - W[row+HFS-1][col+HFS+1] ) + W[row+HFS-1][col+HFS+1] ) );
				}
			}
			
			if( row != HFS )
				v0[(col+HFS)/2] = v1[(col+HFS)/2].xy;
		}
   }
  
   //return dot(s, vec4_splat(1.0))/w;
   return dot(s, vec4_splat(1.0/w));
}

#define shadowPCF fastPCF

#elif PCF_TYPE == PCF_TYPE_FIX4
//see: https://developer.nvidia.com/gpugems/gpugems/part-ii-lighting-and-shadows/chapter-11-shadow-map-antialiasing
float PCF4x4_fix4(shadow_sampler_type shadowsampler, vec4 shadowcoord, uint cascadeidx)
{
	vec2 offset = (vec2)(frac(shadowcoord.xy * 0.5) > 0.25);  // mod
	offset.y += offset.x;  // y ^= x in floating point 
	if (offset.y > 1.1)
		offset.y = 0;

	return (sample_shadow_compare_offset(shadowsampler, shadowcoord, cascadeidx, (offset + vec2(-1.5,  0.5))*u_shadowmap_texelsize)
		   +sample_shadow_compare_offset(shadowsampler, shadowcoord, cascadeidx, (offset + vec2( 0.5,  0.5))*u_shadowmap_texelsize)
		   +sample_shadow_compare_offset(shadowsampler, shadowcoord, cascadeidx, (offset + vec2(-1.5, -1.5))*u_shadowmap_texelsize)
		   +sample_shadow_compare_offset(shadowsampler, shadowcoord, cascadeidx, (offset + vec2( 0.5, -1.5))*u_shadowmap_texelsize)) * 0.25;
}

#define shadowPCF PCF4x4_fix4

#elif PCF_TYPE == PCF_TYPE_SIMPLE

// float PCF(
// 	shadow_sampler_type _sampler,
// 	vec4 _shadowCoord,
// 	float _fTexelSize,
// 	float _fNativeTexelSizeInX)
// {
// 	int m_iPCFBlurForLoopStart = -3;
// 	int m_iPCFBlurForLoopEnd = 4;
// 	float visibility = 0.0;
//     for( int x = m_iPCFBlurForLoopStart; x < m_iPCFBlurForLoopEnd; ++x ) 
//     {
//         for( int y = m_iPCFBlurForLoopStart; y < m_iPCFBlurForLoopEnd; ++y ) 
//         {
// 			vec2 texCoord = _shadowCoord.xy / _shadowCoord.w;
//             float receiver = (_shadowCoord.z) / _shadowCoord.w;
// 			texCoord.x += x*_fNativeTexelSizeInX;
// 			texCoord.y += y*_fTexelSize;
// 			float occluder = texture2D(_sampler, texCoord).x;		
//             visibility += step(occluder, receiver);
//         }
//     }
// 	return visibility / 49.0;	
// }

float PCF(shadow_sampler_type shadowsampler, vec4 shadowcoord, uint cascadeidx)
{
	float visibility = 0;
	const float s = PCF_FILTER_SIZE * 0.5 - 0.5;
	for (float y = -s; y <= s; y += 1.0)
	{
		for (float x = -s; x <= s; x += 1.0)
		{
			visibility += sample_shadow_compare(shadowsampler, shadowcoord, cascadeidx, vec2(x, y) * u_shadowmap_texelsize);
		}
	}
	return visibility / (PCF_FILTER_SIZE * PCF_FILTER_SIZE);
}

#define shadowPCF PCF
#endif //PCF_TYPE

#endif //__SHADOW_FILTERING_PCF__