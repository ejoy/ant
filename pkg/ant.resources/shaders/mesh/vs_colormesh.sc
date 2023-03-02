#include "common/inputs.sh"

$input a_position INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT
$output OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"

#ifdef SCREEN_SPACE
    uniform vec4 u_canvas_size;
#endif

void main()
{
#ifdef SCREEN_SPACE
    gl_Position = vec4((a_position.x / u_canvas_size.x) * 2.0 - 1.0, (a_position.y / u_canvas_size.y) * 2.0 - 1.0, 0.5, 1.0);
#else
    vec4 posWS = transformWS(u_model[0], vec4(a_position, 1.0));
    gl_Position = mul(u_viewProj, posWS);
#endif
#ifdef WITH_COLOR_ATTRIB
    v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB
}