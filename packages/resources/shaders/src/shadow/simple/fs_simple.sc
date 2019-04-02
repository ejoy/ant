$input v_normal, v_viewdir, v_shadowcoord
#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

float hard_shadow(sampler2DShadow shadowSampler, vec4 shadowcoord, float bias)
{
	vec3 texcoord = shadowcoord.xyz/shadowcoord.w;
	return shadow2D(shadowSampler, vec3(texcoord.xy, texcoord.z-bias));
}

void main()
{
	vec3 normal = normalize(v_normal);
	vec3 viewdir = normalize(v_viewdir);

	float visible = hard_shadow(s_shadowmap0, v_shadowcoord, 0.01);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0].xyz, viewdir, shiness)* visible; 
	gl_FragColor.w = 1.0;
}