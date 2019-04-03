$input v_normal, v_viewdir, v_shadowcoord
#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"
#include "common/shadow.sh"

void main()
{
	vec3 normal = normalize(v_normal);
	vec3 viewdir = normalize(v_viewdir);

	float visible = hard_shadow(s_shadowmap0, v_shadowcoord, 0);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0].xyz, viewdir, shiness)* visible; 
	gl_FragColor.w = 1.0;
}