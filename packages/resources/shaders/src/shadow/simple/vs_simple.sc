$input a_position, a_normal
$output v_normal, v_viewdir, v_positionInWS

#include <bgfx_shader.sh>

uniform vec4 u_eyepos;

void main()
{
    vec3 pos = a_position;
	v_positionInWS = mul(u_world[0], vec4(pos, 1.0));
	
	gl_Position = mul(u_viewProj, v_positionInWS);
	vec4 wpos = mul(u_model[0], vec4(pos, 1.0));
	
	v_viewdir = (u_eyepos - wpos).xyz;	
	v_normal = a_normal;	
}