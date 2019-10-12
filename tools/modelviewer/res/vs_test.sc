$input a_position, a_color0
$output v_color0
#include <bgfx_shader.sh>

void main()
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));

#ifdef NEED_COLOR
    v_color0 = a_color0;
#else
    v_color0 = vec4(1.0, 0.0, 0.0, 1.0);
#endif
}