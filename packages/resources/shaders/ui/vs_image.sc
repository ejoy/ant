$input a_position, a_color0, a_texcoord0
$output v_texcoord0, v_color0
#include <bgfx_shader.sh>

void main()
{
	vec2 pos = (a_position * u_viewTexel.xy) * 2.0 - 1.0;
	gl_Position = vec4(pos, 0.0, 1.0);
    v_texcoord0 = a_texcoord0;
    v_color0    = a_color0;
}