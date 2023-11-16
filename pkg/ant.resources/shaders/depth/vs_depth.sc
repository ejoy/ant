//$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3
$input a_position a_indices a_weight

#include <bgfx_shader.sh>
#include "common/transform.sh"

// #ifdef DRAW_INDIRECT
// #include "common/drawindirect.sh"
// #endif //DRAW_INDIRECT

void main()
{
//#ifdef DRAW_INDIRECT
	//transform_drawindirect_worldpos(vs_input, gl_Position);
//#else //!DRAW_INDIRECT
	#if GPU_SKINNING
	mat4 wm = calc_bone_transform(a_indices, a_weight);
	#else
	mat4 wm = u_model[0];
	#endif //GPU_SKINNING
	transform_worldpos(wm, a_position, gl_Position);
//#endif //DRAW_INDIRECT
}