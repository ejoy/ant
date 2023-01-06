$input v_texcoord0
#include <bgfx_shader.sh>
SAMPLER2D(s_tex, 0);
uniform vec4 u_color;
void main()
{
    vec4 color = texture2D(s_tex, v_texcoord0);
	gl_FragColor = color * u_color;
}