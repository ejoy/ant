$input a_position, a_normal
$output v_color0
   
#include <bgfx_shader.sh>

uniform vec4 u_time;

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));	
	v_color0.xyz = normalize(a_normal + u_time.xyz);
	v_color0.w = 1.0;
}