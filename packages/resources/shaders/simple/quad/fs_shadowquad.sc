$input v_texcoord0

#include <bgfx_shader.sh>

#include <common/shadow.sh>

void main()
{
#if defined(SM_ESM)
    sampler2D smTex = s_shadowmap_blur;
#elif defined(SM_HARD)
    sampler2D smTex = s_shadowmap;
#endif //SM_ESM || SM_HARD
    float visable = hardShadow(smTex, vec4(v_texcoord0, 1.0, 1.0), 0.003);
    gl_FragColor = vec4(visable, visable, visable, 1.0);
}