#include "common/inputs.sh"
$input a_position INPUT_INDICES INPUT_WEIGHT

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
	vec4 posWS = transformWS(get_world_matrix(), vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, posWS);
}