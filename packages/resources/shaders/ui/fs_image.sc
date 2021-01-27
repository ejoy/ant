$input v_texcoord0, v_color0
#include <bgfx_shader.sh>
#include <shaderlib.sh>
SAMPLER2D(s_tex, 0);

#include "common/transform.sh"

void main()
{
    #ifdef ENABLE_CLIP_RECT
    check_clip_rotated_rect(gl_FragCoord.xy);
    #endif //ENABLE_CLIP_RECT
    gl_FragColor = texture2D(s_tex, v_texcoord0) * v_color0;
}