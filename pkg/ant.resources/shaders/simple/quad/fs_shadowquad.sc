$input v_texcoord0

#include <bgfx_shader.sh>

#include <common/shadow.sh>

void main()
{
    float visable = hardShadow(s_shadowmap, vec4(v_texcoord0, 1.0, 1.0), 0.003);
    gl_FragColor = vec4(visable, visable, visable, 1.0);
}