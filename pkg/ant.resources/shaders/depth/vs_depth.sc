#include "common/default_inputs_define.sh"
$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3

#include <bgfx_shader.sh>
#ifdef DRAW_INDIRECT
uniform vec4 u_draw_indirect_type;
#endif //DRAW_INDIRECT

#include "common/transform.sh"
#include "common/common.sh"
#include "common/default_inputs_structure.sh"

void main()
{
	VSInput vs_input = (VSInput)0;
	#include "common/default_vs_inputs_getter.sh"

	mat4 wm = get_world_matrix(vs_input);
	transform_pos(wm, vs_input.pos, gl_Position);
}