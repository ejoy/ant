$input v_texcoord0
#include <bgfx_shader.sh>

#include "common/constants.sh"
#include "common/common.sh"
#include <bgfx_compute.sh>
SAMPLER2D(s_scene_ldr_color,  0);

void main()
{

    vec3 current_color = texture2D(s_scene_ldr_color, v_texcoord0).xyz;

    gl_FragColor = vec4(current_color, 1.0);
}