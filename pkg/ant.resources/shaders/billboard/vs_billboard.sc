$input a_position, a_texcoord0
$output v_texcoord0
#include <bgfx_shader.sh>

void main()
{
    vec4 wpos = mul(u_model[0], vec4(a_position, 1.0));
	gl_Position = mul(u_viewProj, wpos);
    v_texcoord0 = a_texcoord0;
}