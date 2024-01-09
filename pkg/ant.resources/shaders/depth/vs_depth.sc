

#ifdef DRAW_INDIRECT

$input a_position i_data0 i_data1 i_data2

#else //!DRAW_INDIRECT

#ifdef GPU_SKINNING
$input a_position a_indices a_weight
#else //!GPU_SKINNING
$input a_position
#endif //GPU_SKINNING

#endif //DRAW_INDIRECT

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
#if GPU_SKINNING
	mat4 wm = calc_bone_transform(a_indices, a_weight);
#else //GPU_SKINNING
	mat4 wm = u_model[0];
#endif //GPU_SKINNING

#ifdef DRAW_INDIRECT
	mat4 hitchmat = mat4(i_data0, i_data1, i_data2, vec4(0.0, 0.0, 0.0, 1.0));
	wm = mul(hitchmat, wm);
#endif //DRAW_INDIRECT

	transform_worldpos(wm, a_position, gl_Position);
}