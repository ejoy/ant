$input v_texcoord0
#include <bgfx_shader.sh>
SAMPLER2D(s_mainview, 0);

void main()
{
    gl_FragColor = texture2D(s_mainview, v_texcoord0);
}