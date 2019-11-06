$input v_texcoord0

#include <bgfx_shader.sh>
#include <shaderlibs.sh>

#include "common/postprocess.sh"

void main()
{
    gl_FragColor = bloom_color(texture2D(s_postprocess_input, v_texcoord0));
}