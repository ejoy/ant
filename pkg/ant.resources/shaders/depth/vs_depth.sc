#include "common/inputs.sh"
$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3

#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"

void main()
{
#ifdef DRAW_INDIRECT
	mediump mat4 wm = get_indirect_wolrd_matrix(i_data0, i_data1, i_data2, u_draw_indirect_type);
#else
	mediump mat4 wm = get_world_matrix();
#endif //DRAW_INDIRECT
	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));
	vec4 clipPos = mul(u_viewProj, posWS);
	clipPos += u_jitter * clipPos.w; // Apply Jittering
	gl_Position = clipPos;
}