$input v_texcoord0
#include <bgfx_shader.sh>

uniform vec4 u_color;
SAMPLER2D(s_basecolor, 0);

void main()
{
	gl_FragColor = u_color * texture2D(s_basecolor, v_texcoord0);
}