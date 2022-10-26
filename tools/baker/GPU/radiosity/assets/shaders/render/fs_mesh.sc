$input v_texcoord0, v_normal, v_viewdir

#include <bgfx_shader.sh>
#include "common/simplelighting.sh"
SAMPLER2D(s_basecolor, 0);

void main()
{
	vec4 color = toLinear(texture2D(s_basecolor, v_texcoord0));
	gl_FragColor.xyz = calc_directional_light(v_normal, u_lightdir.xyz, v_viewdir) * color.xyz;	
	gl_FragColor.w = 1.f;	
}