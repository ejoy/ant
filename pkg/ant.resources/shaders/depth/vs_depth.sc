#ifdef ALPHAMODE_MASK
#define INPUT_TEXCOORD0 a_texcoord0
#else //!ALPHAMODE_MASK
#define INPUT_TEXCOORD0
#endif //ALPHAMODE_MASK

#ifdef DRAW_INDIRECT
$input a_position INPUT_TEXCOORD0 i_data0 i_data1 i_data2
#else //!DRAW_INDIRECT

#ifdef GPU_SKINNING
$input a_position INPUT_TEXCOORD0 a_indices a_weight
#else //!GPU_SKINNING
$input a_position INPUT_TEXCOORD0
#endif //GPU_SKINNING

#endif //DRAW_INDIRECT

#ifdef ALPHAMODE_MASK
$output v_texcoord0
#endif //ALPHAMODE_MASK

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

#ifdef ALPHAMODE_MASK
	v_texcoord0 = a_texcoord0;
#endif //ALPHAMODE_MASK
}