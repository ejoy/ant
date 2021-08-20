$input a_texcoord0, a_normal, a_tangent
$output v_texcoord0, v_normal, v_tangent, v_bitangent

#include <bgfx_shader.sh>

void main()
{
	mat4 wm = u_model[0];
	vec4 posWS = mul(wm, vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, posWS);

	v_texcoord0	= a_texcoord0;
	v_normal	= normalize(mul(wm, vec4(a_normal, 0.0)).xyz);
	v_tangent	= normalize(mul(wm, vec4(a_tangent, 0.0)).xyz);
	v_bitangent	= cross(v_normal, v_tangent);	//left hand
}