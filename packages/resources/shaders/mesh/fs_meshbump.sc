$input v_texcoord0, v_lightdir, v_viewdir	

#include <bgfx_shader.sh>
#include "common/uniforms.sh"	
#include "common/simplelighting.sh"

SAMPLER2D(s_basecolor,  0);	
SAMPLER2D(s_normal, 1);	


void main()	
{	
	vec3 normal = normalize(texture2D(s_normal, v_texcoord0).xyz * 2.0 - 1.0);	
	//normal.z = sqrt(1.0 - dot(normal.xy, normal.xy) );	

	vec4 color = toLinear(texture2D(s_basecolor, v_texcoord0) );	
	gl_FragColor.xyz = calc_directional_light(normal, v_lightdir, v_viewdir, 64) * color.xyz;	
	gl_FragColor.w = 1.f;	
}