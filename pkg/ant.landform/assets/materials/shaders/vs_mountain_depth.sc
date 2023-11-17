$input a_position i_data0 i_data1 i_data2

#include <bgfx_shader.sh>
#include "common/transform.sh"

void main()
{
    mat4 wm = mat4(i_data0, i_data1, i_data2, vec4(0.0, 0.0, 0.0, 1.0));
    transform_worldpos(wm, vec4(a_position, 1.0), gl_Position);
}