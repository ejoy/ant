#include "default/inputs_define.sh"

$input a_position INPUT_COLOR0
$output OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
#ifdef CS_SKINNING
    mat4 wm = u_model[0];
#else //!CS_SKINNING
    mat4 wm = get_world_matrix(vsinput.a_indices, vsinput.a_weight);
#endif //CS_SKINNING

    vec4 posWS = mul(wm, vec4(a_position, 1.0));
	gl_Position = mul(u_viewProj, posWS);
#ifdef WITH_COLOR_ATTRIB
    v_color0 = a_color0;
#endif //WITH_COLOR_ATTRIB
}