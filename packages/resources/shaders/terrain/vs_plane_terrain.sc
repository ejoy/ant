#include "common/inputs.sh"

$input 	a_position a_texcoord0 a_texcoord1
$output v_texcoord0 v_texcoord1 v_normal v_tangent v_bitangent v_stone_type v_posWS

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	mat4 wm = get_world_matrix();
	vec4 posWS = transformWS(wm, vec4(a_position.xyz, 1.0));
	gl_Position = mul(u_viewProj, posWS);

	v_texcoord0	= a_texcoord0;

	v_texcoord1 = a_texcoord1;

	v_normal	= normalize(mul(wm, vec4(0.0, 1.0, 0.0, 0.0)).xyz);

	v_tangent	= normalize(mul(wm, vec4(1.0, 0.0, 0.0, 0.0)).xyz);

	v_bitangent	= cross(v_normal, v_tangent);	//left hand

	v_stone_type     = a_position.w;

	v_posWS     = posWS;
}