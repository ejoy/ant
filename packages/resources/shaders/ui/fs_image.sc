$input v_texcoord0, v_color0
#include <bgfx_shader.sh>
#include <shaderlib.sh>
SAMPLER2D(s_tex, 0);

void main()
{
    gl_FragColor = toLinear(texture2D(s_tex, v_texcoord0) * v_color0);
}