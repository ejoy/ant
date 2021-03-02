#ifndef SINGLE_COLOR
$input v_color0
#endif

#ifdef SINGLE_COLOR
uniform vec4 u_color;
#endif

#include <bgfx_shader.sh>

void main()
{
#ifdef SINGLE_COLOR
    gl_FragColor = u_color;
#else
    gl_FragColor = v_color0;
#endif
}