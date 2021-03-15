$input v_texcoord0, v_texcoord1

#include <bgfx_shader.sh>

SAMPLER2D(s_color, 0);
SAMPLER2D(s_weight, 1);

void main()
{
    vec4 color = texture2D(s_color, v_texcoord0);
    float weight = texture2D(s_weight, v_texcoord1).r;

    gl_FragColor = color * weight;
}