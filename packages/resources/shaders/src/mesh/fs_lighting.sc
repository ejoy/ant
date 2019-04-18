$input v_normal, v_viewdir
#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

void main()
{
	vec3 normal = normalize(v_normal);	
	vec3 viewdir = normalize(v_viewdir);

	float shiness = 0.06;
	gl_FragColor.xyz = calc_directional_light(normal, directional_lightdir[0].xyz, viewdir, shiness); 
	gl_FragColor.w = 1.0;
}