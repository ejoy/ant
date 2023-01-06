$input a_position, a_texcoord0, a_color0
$output v_color0, v_texcoord0
#include <bgfx_shader.sh>
#include "common/transform.sh"

//a_position value is int16 ==> float, int16 range from: [-32768, 32768]
//4096 = 32768 / 8, where 8 is a fix point factor
#define FACTOR 4096.0
void main()
{
	gl_Position = transform_screen_coord_to_ndc(u_model[0], a_position * FACTOR);
	v_texcoord0 = a_texcoord0;
	v_color0    = a_color0;
}
