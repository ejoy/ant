#ifdef GPU_SKINNING
$input a_position a_indices a_weight
#else //!GPU_SKINNING
$input a_position
#endif //GPU_SKINNING

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
#if GPU_SKINNING
	mat4 wm = calc_bone_transform(a_indices, a_weight);
#else //GPU_SKINNING
	mat4 wm = u_model[0];
#endif //GPU_SKINNING
	transform_worldpos(wm, a_position, gl_Position);
}