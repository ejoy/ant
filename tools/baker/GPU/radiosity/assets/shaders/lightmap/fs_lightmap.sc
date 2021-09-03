$input v_texcoord1
#include <bgfx_shader.sh>

SAMPLER2D(s_lightmap, 0);

void main()
{
    gl_FragColor = texture2D(s_lightmap, v_texcoord1);
}