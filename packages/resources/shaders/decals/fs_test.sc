$input v_wpos

#include <bgfx_shader.sh>
SAMPLER2D(s_decal, 0);
uniform mat4 u_decal_mat;

void main()
{
    vec4 decalpos = mul(u_decal_mat, v_wpos);
    vec2 tc = decalpos.xy / decalpos.w;
    tc = tc * 2.0 + 1.0;

    if (0.0 <= tc.x && tc.x <= 1.0 && 
        0.0 <= tc.y && tc.y <= 1.0)
        gl_FragColor = texture2D(s_decal, tc);
    else
        discard;
}