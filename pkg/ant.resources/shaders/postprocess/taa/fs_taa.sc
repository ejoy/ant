$input v_texcoord0
#include <bgfx_shader.sh>

#include "common/constants.sh"
#include "common/common.sh"

#include <bgfx_compute.sh>
SAMPLER2D(s_scene_ldr_color,  0);
SAMPLER2D(s_prev_scene_ldr_color, 1);
SAMPLER2D(s_velocity, 2);

void main()
{
    vec3 current_color = texture2D(s_scene_ldr_color, v_texcoord0).xyz;

    #ifdef TAA_FIRST_FRAME
        gl_FragColor = vec4(current_color, 1.0);
    #else
        vec2 texel_size = vec2(textureSize(s_scene_ldr_color, 0));
        vec2 uv0 = vec2(1.0,  0.0) / texel_size;
        vec2 uv1 = vec2(0.0,  1.0) / texel_size;
        vec2 uv2 = vec2(-1.0, 0.0) / texel_size;
        vec2 uv3 = vec2(0.0, -1.0) / texel_size;

        vec2 delta_uv = texture2D(s_velocity, v_texcoord0).xy;
        vec2 prev_uv = v_texcoord0 - delta_uv;
        vec3 prev_color = texture2D(s_prev_scene_ldr_color, prev_uv).xyz;
    
        vec3 near_color0 = texture2D(s_scene_ldr_color, v_texcoord0 + uv0).xyz;
        vec3 near_color1 = texture2D(s_scene_ldr_color, v_texcoord0 + uv1).xyz;
        vec3 near_color2 = texture2D(s_scene_ldr_color, v_texcoord0 + uv2).xyz;
        vec3 near_color3 = texture2D(s_scene_ldr_color, v_texcoord0 + uv3).xyz;

        vec3 box_min = min(current_color, min(near_color0, min(near_color1, min(near_color2, near_color3))));
        vec3 box_max = max(current_color, max(near_color0, max(near_color1, max(near_color2, near_color3))));

        prev_color = clamp(prev_color, box_min, box_max); 
        float modulation_factor = 0.9;
        vec3 color = mix(current_color, prev_color, modulation_factor);
        gl_FragColor = vec4(color, 1.0);
    #endif
}