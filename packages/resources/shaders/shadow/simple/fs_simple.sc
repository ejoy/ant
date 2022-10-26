$input v_normal, v_viewdir, v_shadowcoord
#include <bgfx_shader.sh>
#include "common/simplelighting.sh"
#include "common/shadow.sh"

void main()
{
	vec3 normal = normalize(v_normal);
	vec3 viewdir = normalize(v_viewdir);

	float visible = min(1.0, hard_shadow(s_shadowmap0, v_shadowcoord, 0) + 0.25);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, u_directional_lightdir.xyz, viewdir, shiness) * visible; 
	gl_FragColor.w = 1.0;
}