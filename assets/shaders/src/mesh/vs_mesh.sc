$input a_position, a_normal, a_color0, a_tex0
$output v_color0, v_normal, v_tex0, v_pos

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	v_pos = mul(u_model[0], vec4(pos, 1.0));

    v_color0 = a_color0;
	v_tex0 = a_tex0;
	v_normal = a_normal;
}