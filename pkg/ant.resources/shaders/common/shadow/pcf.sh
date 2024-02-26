#ifndef __SHADOW_FILTERING_PCF__
#define __SHADOW_FILTERING_PCF__

#include "common/shadow/defines.sh"

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
#ifndef USE_SHADOW_COMPARE
#error "PCF4x4 need shadow2DProj work"
#endif //USE_SHADOW_COMPARE

float sample_shadow_hardware(sampler2DShadow shadowsampler, vec4 shadowcoord, vec2 offset)
{
	const vec4 coord = vec4(shadowcoord.xy + offset, shadowcoord.z, shadowcoord.w);
	return sample_shadow_hardware(shadowsampler, coord);
}

float PCF(shadow_sampler_type shadowsampler, vec4 shadowcoord)
{
	float visibility = 0;
	const float s = u_pcf_kernelsize * 0.5 - 0.5;
	for (float y = -s; y <= s; y += 1.0)
	{
		for (float x = -s; x <= s; x += 1.0)
		{
			visibility += sample_shadow_hardware(shadowsampler, shadowcoord, vec2(x, y) * u_shadowmap_texelsize);
		}
	}
	return visibility / (u_pcf_kernelsize * u_pcf_kernelsize); //0.0625 = 1.0/16.0
}

//see: https://developer.nvidia.com/gpugems/gpugems/part-ii-lighting-and-shadows/chapter-11-shadow-map-antialiasing
float PCF4x4_fix4(shadow_sampler_type shadowsampler, vec4 shadowcoord)
{
	vec2 offset = (vec2)(frac(shadowcoord.xy * 0.5) > 0.25);  // mod
	offset.y += offset.x;  // y ^= x in floating point 
	if (offset.y > 1.1)
		offset.y = 0;

	const float SM_TEXEL_SIZE = 1.0/1024.0;
	return (sample_shadow_hardware(shadowsampler, shadowcoord, (offset + vec2(-1.5,  0.5))*u_shadowmap_texelsize)
		   +sample_shadow_hardware(shadowsampler, shadowcoord, (offset + vec2( 0.5,  0.5))*u_shadowmap_texelsize)
		   +sample_shadow_hardware(shadowsampler, shadowcoord, (offset + vec2(-1.5, -1.5))*u_shadowmap_texelsize)
		   +sample_shadow_hardware(shadowsampler, shadowcoord, (offset + vec2( 0.5, -1.5))*u_shadowmap_texelsize)) * 0.25;
}

#ifdef PCF_FIX4
#define shadowPCF PCF4x4_fix4
#else //!PCF_FIX4
#define shadowPCF PCF
#endif //PCF_FIX4


//code from: https://github.com/TheRealMJP/Shadows

vec2 ComputeReceiverPlaneDepthBias(vec3 texCoordDX, vec3 texCoordDY)
{
    vec2 biasUV = vec2( texCoordDY.y * texCoordDX.z - texCoordDX.y * texCoordDY.z,
                        texCoordDX.x * texCoordDY.z - texCoordDY.x * texCoordDX.z);
    biasUV *= 1.0f / ((texCoordDX.x * texCoordDY.y) - (texCoordDX.y * texCoordDY.x));
    return biasUV;
}

//-------------------------------------------------------------------------------------------------
// Samples the shadow map with a fixed-size PCF kernel optimized with GatherCmp. Uses code
// from "Fast Conventional Shadow Filtering" by Holger Gruen, in GPU Pro.
//-------------------------------------------------------------------------------------------------

float CalcBias(vec3 shadowPosDX, vec3 shadowPosDY) {
    #if UsePlaneDepthBias_
        vec2 texelSize = 1.0f / shadowMapSize;

        vec2 receiverPlaneDepthBias = ComputeReceiverPlaneDepthBias(shadowPosDX, shadowPosDY);

        // Static depth biasing to make up for incorrect fractional sampling on the shadow map grid
        float fractionalSamplingError = dot(vec2(1.0f, 1.0f) * texelSize, abs(receiverPlaneDepthBias));
        return min(fractionalSamplingError, 0.01f);
    #else
        return Bias;
    #endif
}


float SampleShadowMapFixedSizePCF(vec3 shadowPos, float bias) {
    float lightDepth = shadowPos.z;
    lightDepth -= bais;

    const int FS_2 = FilterSize_ / 2;

    vec2 tc = shadowPos.xy;

    vec4 s = 0.0f;
    vec2 stc = (shadowMapSize * tc.xy) + vec2(0.5f, 0.5f);
    vec2 tcs = floor(stc);
    vec2 fc;
    int row;
    int col;
    float w = 0.0f;
    vec4 v1[FS_2 + 1];
    vec2 v0[FS_2 + 1];

    fc.xy = stc - tcs;
    tc.xy = tcs / shadowMapSize;

    for(row = 0; row < FilterSize_; ++row)
        for(col = 0; col < FilterSize_; ++col)
            w += W[row][col];

    // -- loop over the rows
    [unroll]
    for(row = -FS_2; row <= FS_2; row += 2)
    {
        [unroll]
        for(col = -FS_2; col <= FS_2; col += 2)
        {
            float value = W[row + FS_2][col + FS_2];

            if(col > -FS_2)
                value += W[row + FS_2][col + FS_2 - 1];

            if(col < FS_2)
                value += W[row + FS_2][col + FS_2 + 1];

            if(row > -FS_2) {
                value += W[row + FS_2 - 1][col + FS_2];

                if(col < FS_2)
                    value += W[row + FS_2 - 1][col + FS_2 + 1];

                if(col > -FS_2)
                    value += W[row + FS_2 - 1][col + FS_2 - 1];
            }

            if(value != 0.0f)
            {
                float sampleDepth = lightDepth;

                #if UsePlaneDepthBias_
                    // Compute offset and apply planar depth bias
                    vec2 offset = vec2(col, row) * texelSize;
                    sampleDepth += dot(offset, receiverPlaneDepthBias);
                #endif

                v1[(col + FS_2) / 2] = ShadowMap.GatherCmp(ShadowSampler, vec3(tc.xy, cascadeIdx),
                                                                sampleDepth, int2(col, row));
            }
            else
                v1[(col + FS_2) / 2] = 0.0f;

            if(col == -FS_2)
            {
                s.x += (1.0f - fc.y) * (v1[0].w * (W[row + FS_2][col + FS_2]
                                        - W[row + FS_2][col + FS_2] * fc.x)
                                        + v1[0].z * (fc.x * (W[row + FS_2][col + FS_2]
                                        - W[row + FS_2][col + FS_2 + 1.0f])
                                        + W[row + FS_2][col + FS_2 + 1]));
                s.y += fc.y * (v1[0].x * (W[row + FS_2][col + FS_2]
                                        - W[row + FS_2][col + FS_2] * fc.x)
                                        + v1[0].y * (fc.x * (W[row + FS_2][col + FS_2]
                                        - W[row + FS_2][col + FS_2 + 1])
                                        +  W[row + FS_2][col + FS_2 + 1]));
                if(row > -FS_2)
                {
                    s.z += (1.0f - fc.y) * (v0[0].x * (W[row + FS_2 - 1][col + FS_2]
                                            - W[row + FS_2 - 1][col + FS_2] * fc.x)
                                            + v0[0].y * (fc.x * (W[row + FS_2 - 1][col + FS_2]
                                            - W[row + FS_2 - 1][col + FS_2 + 1])
                                            + W[row + FS_2 - 1][col + FS_2 + 1]));
                    s.w += fc.y * (v1[0].w * (W[row + FS_2 - 1][col + FS_2]
                                        - W[row + FS_2 - 1][col + FS_2] * fc.x)
                                        + v1[0].z * (fc.x * (W[row + FS_2 - 1][col + FS_2]
                                        - W[row + FS_2 - 1][col + FS_2 + 1])
                                        + W[row + FS_2 - 1][col + FS_2 + 1]));
                }
            }
            else if(col == FS_2)
            {
                s.x += (1 - fc.y) * (v1[FS_2].w * (fc.x * (W[row + FS_2][col + FS_2 - 1]
                                        - W[row + FS_2][col + FS_2]) + W[row + FS_2][col + FS_2])
                                        + v1[FS_2].z * fc.x * W[row + FS_2][col + FS_2]);
                s.y += fc.y * (v1[FS_2].x * (fc.x * (W[row + FS_2][col + FS_2 - 1]
                                        - W[row + FS_2][col + FS_2] ) + W[row + FS_2][col + FS_2])
                                        + v1[FS_2].y * fc.x * W[row + FS_2][col + FS_2]);
                if(row > -FS_2) {
                    s.z += (1 - fc.y) * (v0[FS_2].x * (fc.x * (W[row + FS_2 - 1][col + FS_2 - 1]
                                        - W[row + FS_2 - 1][col + FS_2])
                                        + W[row + FS_2 - 1][col + FS_2])
                                        + v0[FS_2].y * fc.x * W[row + FS_2 - 1][col + FS_2]);
                    s.w += fc.y * (v1[FS_2].w * (fc.x * (W[row + FS_2 - 1][col + FS_2 - 1]
                                        - W[row + FS_2 - 1][col + FS_2])
                                        + W[row + FS_2 - 1][col + FS_2])
                                        + v1[FS_2].z * fc.x * W[row + FS_2 - 1][col + FS_2]);
                }
            }
            else
            {
                s.x += (1 - fc.y) * (v1[(col + FS_2) / 2].w * (fc.x * (W[row + FS_2][col + FS_2 - 1]
                                    - W[row + FS_2][col + FS_2 + 0] ) + W[row + FS_2][col + FS_2 + 0])
                                    + v1[(col + FS_2) / 2].z * (fc.x * (W[row + FS_2][col + FS_2 - 0]
                                    - W[row + FS_2][col + FS_2 + 1]) + W[row + FS_2][col + FS_2 + 1]));
                s.y += fc.y * (v1[(col + FS_2) / 2].x * (fc.x * (W[row + FS_2][col + FS_2-1]
                                    - W[row + FS_2][col + FS_2 + 0]) + W[row + FS_2][col + FS_2 + 0])
                                    + v1[(col + FS_2) / 2].y * (fc.x * (W[row + FS_2][col + FS_2 - 0]
                                    - W[row + FS_2][col + FS_2 + 1]) + W[row + FS_2][col + FS_2 + 1]));
                if(row > -FS_2) {
                    s.z += (1 - fc.y) * (v0[(col + FS_2) / 2].x * (fc.x * (W[row + FS_2 - 1][col + FS_2 - 1]
                                            - W[row + FS_2 - 1][col + FS_2 + 0]) + W[row + FS_2 - 1][col + FS_2 + 0])
                                            + v0[(col + FS_2) / 2].y * (fc.x * (W[row + FS_2 - 1][col + FS_2 - 0]
                                            - W[row + FS_2 - 1][col + FS_2 + 1]) + W[row + FS_2 - 1][col + FS_2 + 1]));
                    s.w += fc.y * (v1[(col + FS_2) / 2].w * (fc.x * (W[row + FS_2 - 1][col + FS_2 - 1]
                                            - W[row + FS_2 - 1][col + FS_2 + 0]) + W[row + FS_2 - 1][col + FS_2 + 0])
                                            + v1[(col + FS_2) / 2].z * (fc.x * (W[row + FS_2 - 1][col + FS_2 - 0]
                                            - W[row + FS_2 - 1][col + FS_2 + 1]) + W[row + FS_2 - 1][col + FS_2 + 1]));
                }
            }

            if(row != FS_2)
                v0[(col + FS_2) / 2] = v1[(col + FS_2) / 2].xy;
        }
    }

    return dot(s, 1.0f) / w;
}

#endif //__SHADOW_FILTERING_PCF__