#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
#include "common/default_inputs_structure.sh"

void CUSTOM_VS_FUNC(in VSInput vs_input, inout VSOutput vs_output)
{
	mat4 wm = get_world_matrix(vs_input);
	transform_pos(wm, vs_input.pos, vs_output.clip_pos);
}