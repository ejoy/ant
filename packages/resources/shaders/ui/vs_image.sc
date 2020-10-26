$input a_position, a_color0, a_texcoord0
$output v_texcoord0, v_color0
#include <bgfx_shader.sh>
#include "common/transform.sh"
void main()
{
	gl_Position = transform_screen_coord_to_ndc(u_model[0], a_position);
    v_texcoord0 = a_texcoord0;
    v_color0    = a_color0;
}