$input a_position, a_color0
$output v_color0
#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));    
    v_color0 = a_color0;
}