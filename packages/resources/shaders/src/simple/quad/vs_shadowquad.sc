$input a_position, a_texcoord0
$output v_texcoord0
#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position.w = 1.0;
	gl_Position.xyz = vec3(pos.xy * u_viewTexel.xy, pos.z);
    v_texcoord0 = a_texcoord0;
}