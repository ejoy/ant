#ifdef GPU_SKINNING
#define BGFX_CONFIG_MAX_BONES 128
$input a_position, a_indices, a_weight
#else //!GPU_SKINNING
$input a_position
#endif //GPU_SKINNING

$output v_position

#include <bgfx_shader.sh>
#ifdef GPU_SKINNING
#include "common/transform.sh"
#endif //GPU_SKINNING

void main()
{
	vec4 pos = vec4(a_position, 1.0);
#ifdef GPU_SKINNING
	mat4 w = calc_bone_transform(a_indices, a_weight);
	vec4 worldpos = mul(w, pos);
	gl_Position = mul(u_viewProj, worldpos);
#else //!GPU_SKINNING
	gl_Position = mul(u_modelViewProj, pos);	
#endif //GPU_SKINNING
#ifdef DEPTH_LINEAR
	v_position = gl_Position;
#endif //DEPTH_LINEAR
}