$input a_position;

#include <bgfx_shader.sh>

void main()
{
    gl_Position = vec4(a_position, 1.0);
}