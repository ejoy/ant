#include "common/inputs.sh"
$input a_position a_normal INPUT_INDICES INPUT_WEIGHT INPUT_INSTANCE

#include <bgfx_shader.sh>
#include "common/transform.sh"


void main()
{
	mat4 wm = get_world_matrix();
#ifdef HEAP_MESH
	wm[0][3] = wm[0][3] + i_data0.x;
	wm[1][3] = wm[1][3] + i_data0.y;
	wm[2][3] = wm[2][3] + i_data0.z;
#endif //HEAP_MESH
	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));
	gl_Position   = mul(u_viewProj, posWS);	
}