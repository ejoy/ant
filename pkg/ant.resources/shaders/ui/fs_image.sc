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

    vec4 texcolor = texture2D(s_tex, v_texcoord0);
    #ifdef ENABLE_IMAGE_GRAY
    gl_FragColor = vec4(vec3_splat(dot(vec3(0.2126, 0.7152, 0.0722), texcolor.rgb)) * v_color0.rgb, v_color0.a * texcolor.a);
    #else //!ENABLE_IMAGE_GRAY
    gl_FragColor = texcolor * v_color0;
    #endif //ENABLE_IMAGE_GRAY
}