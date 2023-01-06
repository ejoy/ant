$input a_position
#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	gl_Position = map_screen_coord_to_ndc(a_position);
}