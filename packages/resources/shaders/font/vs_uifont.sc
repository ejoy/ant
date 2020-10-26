$input a_position, a_texcoord0, a_color0
$output v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "common/transform.sh"
void main()
{
	gl_Position = transform_screen_coord_to_ndc(u_model[0], a_position * 8192.0);
	v_color0 = a_color0;
	v_texcoord0 = a_texcoord0;
}
