#include "common/inputs.sh"
DEF_SKINNING_INPUTS3(a_normal, a_tangent, a_texcoord0)

$output v_texcoord0, v_posWS, v_normal, v_tangent, v_bitangent

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	mat4 wm = get_world_matrix();
	v_posWS = mul(wm, vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, v_posWS);
#ifdef ENABLE_SHADOW
	v_posWS.w = mul(u_view, v_posWS).z;
#endif //ENABLE_SHADOW

	//TODO: normal and tangent should use inverse transpose matrix
	v_normal	= normalize(mul(wm, vec4(a_normal, 0.0)).xyz);
	v_tangent	= normalize(mul(wm, vec4(a_tangent, 0.0)).xyz);
	v_bitangent	= cross(v_normal, v_tangent);	//left hand

	v_texcoord0	= a_texcoord0;
}