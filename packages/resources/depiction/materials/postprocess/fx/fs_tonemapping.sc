$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"

void main()
{
    vec4 c = texture2D(s_postprocess_input, v_texcoord0);

    gl_FragColor.rgb = c.rgb / (1 + c.rgb);
    gl_FragColor.a = saturate(c.a);
}