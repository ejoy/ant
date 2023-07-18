#include "common/default_inputs_define.sh"

$input a_position INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT
$output OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/default_inputs_structure.sh"

#ifdef SCREEN_SPACE
uniform vec4 u_canvas_size;
#endif //SCREEN_SPACE

void main()
{
#ifdef SCREEN_SPACE
    gl_Position = vec4((a_position.xy / u_canvas_size.xy) * 2.0 - 1.0, 0.5, 1.0);
#else //!SCREEN_SPACE
	VSInput vs_input = (VSInput)0;
	#include "common/default_vs_inputs_getter.sh"
    mat4 wm = get_world_matrix(vs_input);
    transform_pos(wm, a_position, gl_Position);
#endif //SCREEN_SPACE
#ifdef WITH_COLOR_ATTRIB
    v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB
}