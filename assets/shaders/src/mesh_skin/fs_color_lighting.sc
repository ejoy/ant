$input v_normal, v_viewdir, v_color0
#include "common.sh"
#include "common/lighting.sh"

SAMPLER2D(s_basecolor, 0);

uniform vec4 directional_lightdir[1];
uniform vec3 u_eyepos;

void main()
{
	vec3 normal = normalize(v_normal);
	vec3 color = v_color0.xyz;
	vec3 viewdir = normalize(v_viewdir);

	//gl_FragColor.xyz = directional_lightdir[0].xyz;
	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0].xyz, viewdir, shiness) * color; 
	gl_FragColor.w = 1.0;
}