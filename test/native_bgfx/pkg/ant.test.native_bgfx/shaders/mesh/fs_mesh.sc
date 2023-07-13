#include <bgfx_shader.sh>

uniform vec4 u_color;
SAMPLER2D(s_tex, 0);

void main()
{
	gl_FragColor = texture2D(s_tex, vec2(0, 0));
}