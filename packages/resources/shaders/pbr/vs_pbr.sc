#include "common/inputs.sh"
DEF_SKINNING_INPUTS2(a_normal, a_texcoord0)

$output v_texcoord0, v_normal, v_posWS

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	vec4 worldpos = mul(get_world_matrix(), vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, worldpos);
#ifdef ENABLE_SHADOW
	v_posWS       = vec4(worldpos.xyz, mul(u_view, worldpos).z);
#else //!ENABLE_SHADOW
	v_posWS       = worldpos;
#endif //ENABLE_SHADOW
	v_texcoord0   = a_texcoord0;

	// normal need recalculate after tranform to world space
	v_normal	  = normalize(mul(u_model[0], vec4(a_normal.xyz, 0.0))).xyz;
}