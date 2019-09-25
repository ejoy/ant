$input v_normal, v_color0, v_viewdir
#include "common.sh"
#include "common/uniforms.sh"
#include "common/lighting.sh"

SAMPLER2D(s_basecolor, 0);

// uniform vec3 u_eyepos;

void main()
{
	vec3 normal = normalize(v_normal);
	vec4 color = toLinear(v_color0);
	vec3 viewdir = normalize(v_viewdir);

	float shiness = 0.06;
	//gl_FragColor.xyz = 
    vec3 light = calc_directional_light(normal, viewdir, viewdir, shiness);
    gl_FragColor.xyz = (clamp(light.x,0.0,1.0)+1.0)*color.xyz*0.5;
	gl_FragColor.w = 1.0;
    gl_FragColor = toGamma(gl_FragColor);
}