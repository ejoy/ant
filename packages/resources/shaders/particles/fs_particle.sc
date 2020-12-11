#ifdef SUB_TEX
$input v_texcoord0, v_texcoord1, v_color0
#else //!SUB_TEX
$input v_texcoord0, v_color0
#endif //SUB_TEX
#include <bgfx_shader.sh>

SAMPLER2D(s_tex, 0);
#ifdef SUB_TEX
SAMPLER2D(s_subtex, 0);
#endif //SUB_TEX

void main()
{
    vec4 texcolor = texture2D(s_tex, v_texcoord0);
    #ifdef SUB_TEX
    vec4 subcolor = texture2D(s_subtex, v_texcoord1);
    texcolor *= subcolor;
    #endif //SUB_TEX
    gl_FragColor = texcolor * v_color0;
}