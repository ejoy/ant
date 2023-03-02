$input v_texcoord0

#include <bgfx_shader.sh>

SAMPLER2D(s_mask, 0);

uniform vec4 u_color;

void main()
{
    float mask = texture2D(s_mask, v_texcoord0).r;
    gl_FragColor = vec4(u_color.rgb, mask);
}