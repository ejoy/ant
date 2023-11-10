$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"

void main()
{
    vec4 scene_color = texture2D(s_scene_color, v_texcoord0);
    float blur_alpha = texture2D(s_scene_depth, v_texcoord0);
    gl_FragColor = vec4(scene_color.xyz, blur_alpha);
}