$input a_position, a_normal, a_tangent, a_tex0
$output v_normal, v_tangent, v_bitangent, v_tex0, v_pos

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	v_pos = mul(u_model[0], vec4(pos, 1.0));

	v_tex0 = a_tex0;

	v_normal = normalize(mul(u_modelView, a_normal.xyz));
	v_tangent = normalize(mul(u_modelView, a_tangent.xyz));
	v_bitangent = cross(v_normal, v_tangent) * a_tangent.w;
}