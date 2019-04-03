vec4 calc_shadow_texcoord(mat4 lightviewproj, vec3 pos, vec3 normal, float offset)
{
	vec3 posOffset = pos + normal * offset;
	return mul(lightviewproj, vec4(posOffset, 1.0) );
}

float hard_shadow(sampler2DShadow shadowSampler, vec4 shadowcoord, float bias)
{
	vec3 texcoord = shadowcoord.xyz/shadowcoord.w;
	return shadow2D(shadowSampler, vec3(texcoord.xy, texcoord.z-bias));
}