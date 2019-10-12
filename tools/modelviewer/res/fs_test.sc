
$input v_color0

#include <bgfx_shader.sh>

SAMPLER2D(s_basecolor, 0);

void main()
{
    vec4 c = texture2D(s_basecolor, v_color0.xy);
    gl_FragColor = c;
}