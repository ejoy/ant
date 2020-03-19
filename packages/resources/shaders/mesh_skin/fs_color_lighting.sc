$input v_normal, v_viewdir, v_color0
#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

SAMPLER2D(s_basecolor, 0);

void main()
{
	vec3 normal = normalize(v_normal);
	vec3 color = v_color0.xyz;
	vec3 viewdir = normalize(v_viewdir);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir.xyz, viewdir, shiness) * color; 
	gl_FragColor.w = 1.0;
}