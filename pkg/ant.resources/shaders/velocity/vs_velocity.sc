#include "common/inputs.sh"

$input 	a_position 
$output v_prev_pos v_cur_pos

#include <bgfx_shader.sh>
#include "common/transform.sh"
#include "common/common.sh"
uniform mat4 u_prev_mvp;
void main()
{
    mediump mat4 wm = get_world_matrix();
	highp vec4 posWS = transformWS(wm, mediump vec4(a_position, 1.0));
	vec4 clipPos = mul(u_viewProj, posWS);
	v_cur_pos  = clipPos;
	gl_Position = clipPos;
	if(u_first_frame.x == 0){
		v_prev_pos = v_cur_pos;
	}
	else{
		v_prev_pos = mul(u_prev_mvp, vec4(a_position, 1.0));
	}
}