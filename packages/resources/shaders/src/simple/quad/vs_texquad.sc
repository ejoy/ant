$input a_position, a_texcoord0
$output v_texcoord0
#include <bgfx_shader.sh>

void main()
{
    vec3 pos = vec3(a_position.xy * u_viewTexel.xy, a_position.z);
	pos.xy = pos.xy * 2.0 - 1.0;
	gl_Position = vec4(pos, 1.0);
    v_texcoord0 = a_texcoord0;
}