$input v_texcoord0
#include <bgfx_shader.sh>
#include "common/uniforms.sh"

void main()
{
    gl_FragColor = texture2D(s_mianview, v_texcoord0);
}