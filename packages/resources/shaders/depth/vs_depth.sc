#include "common/inputs.sh"
DEF_SKINNING_INPUTS0()

$output v_position

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	vec4 worldpos = mul(get_world_matrix(), vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, worldpos);
#ifdef DEPTH_LINEAR
	v_position = gl_Position;
#endif //DEPTH_LINEAR
}