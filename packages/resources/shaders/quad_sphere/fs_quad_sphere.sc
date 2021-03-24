$input v_texcoord0, v_texcoord1

#include <bgfx_shader.sh>

SAMPLER2D(s_weight, 0);
SAMPLER2D(s_color, 1);

void main()
{
    float weight    = texture2D(s_weight, v_texcoord0).r;
    vec4 color      = texture2D(s_color, v_texcoord1);

    gl_FragColor = color * weight;
}