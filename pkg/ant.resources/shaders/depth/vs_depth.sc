#include "default/inputs_define.sh"
$input a_position INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE1 INPUT_INSTANCE2 INPUT_INSTANCE3

#include <bgfx_shader.sh>

#include "common/transform.sh"
#include "default/inputs_structure.sh"

#ifdef DRAW_INDIRECT
#include "common/drawindirect.sh"
#endif //DRAW_INDIRECT

void main()
{
	VSInput vs_input = (VSInput)0;
	#include "default/vs_inputs_getter.sh"

#ifdef DRAW_INDIRECT
	transform_drawindirect_worldpos(vs_input, gl_Position);
#else //!DRAW_INDIRECT
	mat4 wm = get_world_matrix(vs_input);
	transform_worldpos(wm, vs_input.pos, gl_Position);
#endif //DRAW_INDIRECT
}