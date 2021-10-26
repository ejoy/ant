#include "common/inputs.sh"

$input a_position INPUT_COLOR0 INPUT_INDICES INPUT_WEIGHT
$output OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
    mat4 wm = get_world_matrix();
    vec4 posWS = mul(wm, vec4(a_position, 1.0));
#ifdef CYLINDER_TRANSFORM
    gl_Position = do_cylinder_transform(posWS);
#else //!CYLINDER_TRANSFORM
	gl_Position = mul(u_viewProj, posWS);
#endif //CYLINDER_TRANSFORM

#ifdef WITH_COLOR_ATTRIB
    v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB
}