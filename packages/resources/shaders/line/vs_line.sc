#ifdef SINGLE_COLOR
$input a_position
#else
$input a_position, a_color0
$output v_color0
#endif

#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
#ifdef SINGLE_COLOR
    v_color0 = a_color0;
#endif 
}