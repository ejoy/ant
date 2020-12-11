#ifdef SUB_TEX
$input a_position, a_color0, a_texcoord0, a_texcoord1
$output v_color0, v_texcoord0, v_texcoord1
#else //!SUB_TEX
$input a_position, a_color0, a_texcoord0
$output v_color0, v_texcoord0
#endif //SUB_TEX

#include <bgfx_shader.sh>

void main()
{
    vec4 pos = vec4(a_position, 1.0);
    v_color0 = a_color0;
    v_texcoord0 = a_texcoord0;
    #ifdef SUB_TEX
    v_texcoord1 = a_texcoord1;
    #endif //SUB_TEX
    gl_Position = mul(u_modelViewProj, pos);
}