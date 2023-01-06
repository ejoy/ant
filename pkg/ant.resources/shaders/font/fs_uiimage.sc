$input v_color0, v_texcoord0
#include <bgfx_shader.sh>

SAMPLER2D(s_tex, 0);

void main()
{
    gl_FragColor = v_color0 * texture2D(s_tex, v_texcoord0);
}