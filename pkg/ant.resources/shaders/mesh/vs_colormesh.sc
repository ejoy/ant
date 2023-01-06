#include "common/inputs.sh"

$input a_position INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT
$output OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
    vec4 posWS = transformWS(get_world_matrix(), vec4(a_position, 1.0));
    gl_Position = mul(u_viewProj, posWS);
#ifdef WITH_COLOR_ATTRIB
    v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB
}