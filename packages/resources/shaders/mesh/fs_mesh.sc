$input v_normal, v_texcoord0, v_viewdir
#include "common.sh"
#include "common/lighting.sh"

SAMPLER2D(s_basecolor, 0);

uniform vec4 directional_lightdir[1];
uniform vec3 u_eyepos;

void main()
{
	vec3 normal = normalize(v_normal);
	vec4 color = toLinear(texture2D(s_basecolor, v_texcoord0));
	vec3 viewdir = normalize(v_viewdir);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0].xyz, viewdir, shiness) * color.xyz; 
	gl_FragColor.w = 1.0;
}