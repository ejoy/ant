$input v_decalpos

#include <bgfx_shader.sh>
SAMPLER2D(s_decal, 0);

void main()
{
    vec2 tc = v_decalpos.xy / v_decalpos.w;
    gl_FragColor = texture2D(s_decal, tc);
}