#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "common/default_inputs_structure.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
#ifdef DRAW_INDIRECT
	mediump mat4 wm = get_indirect_world_matrix(vs_input.idata0, vs_input.idata1, vs_input.idata2, u_draw_indirect_type);
#else
	mediump mat4 wm = get_world_matrix_default(vs_input);
#endif //DRAW_INDIRECT

	highp vec4 posWS = transformWS(wm, mediump vec4(vs_input.pos, 1.0));
	vec4 clipPos = mul(u_viewProj, posWS);
	clipPos += u_jitter * clipPos.w; // Apply Jittering
	vs_output.clip_pos = clipPos;
}