$input a_position, a_normal
$output v_wpos

#include <bgfx_shader.sh>

void main()
{
    vec4 wpos = mul(u_model[0], vec4(a_position, 1.0));
	vec4 wnormal = mul(u_model[0], vec4(a_normal, 0.0));
	wpos = wpos + wnormal * 0.0001;
	gl_Position = mul(u_viewProj, wpos);
	v_wpos = wpos;
}