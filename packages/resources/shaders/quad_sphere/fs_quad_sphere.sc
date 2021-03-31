#ifdef WITH_MASK
$input v_texcoord0, v_texcoord1
#else //!WITH_MASK
$input v_texcoord0
#endif//WITH_MASK

#include <bgfx_shader.sh>

SAMPLER2D(s_color, 0);
#ifdef WITH_MASK
SAMPLER2D(s_mask, 1);
#endif //WITH_MASK

void main()
{
    vec4 color      = texture2D(s_color, v_texcoord0);
#ifdef WITH_MASK
    float weight    = texture2D(s_mask, v_texcoord1).r;
    gl_FragColor = weight * color;
#else //!WITH_MASK
    gl_FragColor = color;
#endif //WITH_MASK
}