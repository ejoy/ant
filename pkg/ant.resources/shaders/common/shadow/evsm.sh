#ifndef __SHADOW_EVSM_SH__
#define __SHADOW_EVSM_SH__

#ifdef SM_VSM
float VSM(
	shadow_sampler_type _sampler,
	vec4 _shadowCoord,
	float _depthMultiplier, float _minVariance) 
{
	vec2 texCoord = _shadowCoord.xy / _shadowCoord.w;
	bool outside = any(greaterThan(texCoord, vec2_splat(1.0)))
				|| any(lessThan   (texCoord, vec2_splat(0.0)))
				 ;

	if (outside)
	{
		return 1.0;
	}

	float receiver = (_shadowCoord.z) / _shadowCoord.w * _depthMultiplier;
	vec2  occluder = texture2D(_sampler, texCoord);
	float depth    = occluder.x * _depthMultiplier;
	float depthSq  = occluder.y * _depthMultiplier;
	if (receiver > depth)
	{
		return 1.0;
	}	
	float variance = max(depth * depth - depthSq, _minVariance);
	float d = depth - receiver;
	float visibility = variance / (variance + d * d);
	return visibility;
}
#endif //SM_VSM

#ifdef SM_EVSM
float ESM(
	shadow_sampler_type _sampler,
	vec4 _shadowCoord,
	float _depthMultiplier) 
{
	vec2 texCoord = _shadowCoord.xy / _shadowCoord.w;
	bool outside = any(greaterThan(texCoord, vec2_splat(1.0)))
				|| any(lessThan   (texCoord, vec2_splat(0.0)))
				 ;

	if (outside)
	{
		return 1.0;
	}	
	float receiver = (_shadowCoord.z + 0.005) / _shadowCoord.w;

	float occluder = texture2D(_sampler, texCoord);	

	float visibility = clamp(exp(_depthMultiplier * (receiver - occluder) ), 0.0, 1.0);
	return visibility;
}
#endif //SM_EVSM

#endif //__SHADOW_EVSM_SH__