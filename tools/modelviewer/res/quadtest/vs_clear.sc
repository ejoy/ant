$input a_position, a_color0
$output v_color0
#include <bgfx_shader.sh>

void main()
{
    gl_Position = vec4(a_position.xyz, 1.0);
    v_color0 = a_color0;
}