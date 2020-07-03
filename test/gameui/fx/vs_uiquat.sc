$input a_position, a_color0
$output v_color0
#include <bgfx_shader.sh>

void main()
{
	vec2 pos = a_position * u_viewTexel.xy * 8192.0f;
	gl_Position = vec4(pos.x - 1.0 , 1.0 - pos.y , 0, 1.0);
	v_color0 = a_color0;
}
