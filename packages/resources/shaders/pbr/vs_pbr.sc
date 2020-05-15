#ifdef GPU_SKINNING
$input  a_position, a_normal, a_texcoord0, a_indices, a_weight
#else //!GPU_SKINNING
$input  a_position, a_normal, a_texcoord0
#endif //GPU_SKINNING
$output v_texcoord0, v_normal, v_posWS

#include <bgfx_shader.sh>
#include "common/uniforms.sh"
#include "common/transform.sh"

void main()
{
    vec4 pos      = vec4(a_position, 1.0);
	vec4 worldpos =
#ifdef GPU_SKINNING
	transform_skin_position(pos, a_indices, a_weight);
#else //!GPU_SKINNING
	mul(u_model[0], pos);
#endif //GPU_SKINNING
	
	gl_Position   = mul(u_viewProj, worldpos);
	v_posWS       = vec4(worldpos.xyz, mul(u_view, worldpos).z);
	v_texcoord0   = a_texcoord0;

	// normal need recalculate after tranform to world space
	v_normal	  = normalize(mul(u_model[0], vec4(a_normal.xyz, 0.0))).xyz;
}