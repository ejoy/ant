
#define u_ambientPass    u_params0.x
#define u_lightingPass   u_params0.y

#define u_shadowMapBias   u_params1.x
#define u_shadowMapParam0 u_params1.z
#define u_shadowMapParam1 u_params1.w

#define u_shadowMapShowCoverage u_params2.y
#define u_shadowMapTexelSize    u_params2.z

#define u_spotDirection   u_lightSpotDirectionInner.xyz
#define u_spotInner       u_lightSpotDirectionInner.w
#define u_lightAttnParams u_lightAttenuationSpotOuter.xyz
#define u_spotOuter       u_lightAttenuationSpotOuter.w

// Pcf
#define u_shadowMapPcfMode     u_shadowMapParam0
#define u_shadowMapNoiseAmount u_shadowMapParam1

// Vsm
#define u_shadowMapMinVariance     u_shadowMapParam0
#define u_shadowMapDepthMultiplier u_shadowMapParam1

// Esm
#define u_shadowMapHardness        u_shadowMapParam0
#define u_shadowMapDepthMultiplier u_shadowMapParam1

float visibility = 0.0 ;
{
	vec3 colorCoverage;

#if SM_CSM
	vec2 texelSize = vec2_splat( u_shadowMapTexelSize);

	vec2 texcoord1 = v_texcoord4.xy/v_texcoord4.w;
	vec2 texcoord2 = v_texcoord5.xy/v_texcoord5.w;
	vec2 texcoord3 = v_texcoord6.xy/v_texcoord6.w;
	vec2 texcoord4 = v_texcoord7.xy/v_texcoord7.w;

	bool selection0 = all(lessThan(texcoord1, vec2_splat(0.99))) && all(greaterThan(texcoord1, vec2_splat(0.01)));
	bool selection1 = all(lessThan(texcoord2, vec2_splat(0.99))) && all(greaterThan(texcoord2, vec2_splat(0.01)));
	bool selection2 = all(lessThan(texcoord3, vec2_splat(0.99))) && all(greaterThan(texcoord3, vec2_splat(0.01)));
	bool selection3 = all(lessThan(texcoord4, vec2_splat(0.99))) && all(greaterThan(texcoord4, vec2_splat(0.01)));

	if (selection0)
	{
		vec4 shadowcoord = v_texcoord4;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(-coverage, coverage, -coverage);
		visibility = computeVisibility(s_shadowMap0
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
	else if (selection1)
	{
		vec4 shadowcoord = v_texcoord5;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(coverage, coverage, -coverage);
		visibility = computeVisibility(s_shadowMap1
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize/2.0
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
	else if (selection2)
	{
		vec4 shadowcoord = v_texcoord6;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(-coverage, -coverage, coverage);
		visibility = computeVisibility(s_shadowMap2
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize/3.0
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	}
	else if( selection3 )     //selection3
	{
		vec4 shadowcoord = v_texcoord7;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.4;
		colorCoverage = vec3(coverage, -coverage, -coverage);
		visibility = computeVisibility(s_shadowMap3
						, shadowcoord
						, u_shadowMapBias
						, u_smSamplingParams
						, texelSize/4.0
						, u_shadowMapDepthMultiplier
						, u_shadowMapMinVariance
						, u_shadowMapHardness
						);
	} 


#elif SM_OMNI
   /*
	vec2 texelSize = vec2_splat(u_shadowMapTexelSize/4.0);

	vec4 faceSelection;
	vec3 pos = v_position.xyz;
	faceSelection.x = dot(u_tetraNormalGreen.xyz,  pos);
	faceSelection.y = dot(u_tetraNormalYellow.xyz, pos);
	faceSelection.z = dot(u_tetraNormalBlue.xyz,   pos);
	faceSelection.w = dot(u_tetraNormalRed.xyz,    pos);

	vec4 shadowcoord;
	float faceMax = max(max(faceSelection.x, faceSelection.y), max(faceSelection.z, faceSelection.w));
	if (faceSelection.x == faceMax)
	{
		shadowcoord = v_texcoord1;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(-coverage, coverage, -coverage);
	}
	else if (faceSelection.y == faceMax)
	{
		shadowcoord = v_texcoord2;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(coverage, coverage, -coverage);
	}
	else if (faceSelection.z == faceMax)
	{
		shadowcoord = v_texcoord3;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(-coverage, -coverage, coverage);
	}
	else // (faceSelection.w == faceMax)
	{
		shadowcoord = v_texcoord4;

		float coverage = texcoordInRange(shadowcoord.xy/shadowcoord.w) * 0.3;
		colorCoverage = vec3(coverage, -coverage, -coverage);
	}

	visibility = computeVisibility(s_shadowMap0
					, shadowcoord
					, u_shadowMapBias
					, u_smSamplingParams
					, texelSize
					, u_shadowMapDepthMultiplier
					, u_shadowMapMinVariance
					, u_shadowMapHardness
					);
	*/
#else
    /*
	vec2 texelSize = vec2_splat(u_shadowMapTexelSize);

	float coverage = texcoordInRange(v_shadowcoord.xy/v_shadowcoord.w) * 0.3;
	colorCoverage = vec3(coverage, -coverage, -coverage);

	visibility = computeVisibility(s_shadowMap0
					, v_shadowcoord
					, u_shadowMapBias
					, u_smSamplingParams
					, texelSize
					, u_shadowMapDepthMultiplier
					, u_shadowMapMinVariance
					, u_shadowMapHardness
					);
	 */
#endif

	visibility += 0.5;
	
	// if(u_shadowMapTexelSize == 1.0/1024)
	//    gl_FragColor.xyz = vec3(1,0,0);
	// else 
	//    gl_FragColor.xyz = vec3(0,1,0);
	// gl_FragColor.xyz = vec3( visibility,visibility,visibility);
}




