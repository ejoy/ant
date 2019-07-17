#include <bgfx_shader.sh>

uniform vec4 u_outlinecolor;

void main()
{
    gl_FragColor = u_outlinecolor;
}