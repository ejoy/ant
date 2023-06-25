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
    vec2 uv0 = vec2(1.0, 0.0) / vec2(textureSize(s_scene_ldr_color, 0));
    vec2 uv1 = vec2(0.0, 1.0) / vec2(textureSize(s_scene_ldr_color, 0));
    vec2 uv2 = vec2(-1.0, 0.0) / vec2(textureSize(s_scene_ldr_color, 0));
    vec2 uv3 = vec2(0.0, -1.0) / vec2(textureSize(s_scene_ldr_color, 0));
/*      vec2 uv4 = vec2(1.0, 1.0) / vec2(textureSize(s_scene_ldr_color, 0));
    vec2 uv5 = vec2(-1.0, -1.0) / vec2(textureSize(s_scene_ldr_color, 0));
    vec2 uv6 = vec2(-1.0, 1.0) / vec2(textureSize(s_scene_ldr_color, 0));
    vec2 uv7 = vec2(1.0, -1.0) / vec2(textureSize(s_scene_ldr_color, 0)); 
 */
    vec3 current_color = texture2D(s_scene_ldr_color, v_texcoord0).xyz;
    vec2 delta_uv = texture2D(s_velocity, v_texcoord0).xy;
    vec2 prev_uv = v_texcoord0 - delta_uv;
    vec3 prev_color = texture2D(s_prev_scene_ldr_color, prev_uv).xyz;
 
    vec3 near_color0 = texture2D(s_scene_ldr_color, v_texcoord0 + uv0).xyz;
    vec3 near_color1 = texture2D(s_scene_ldr_color, v_texcoord0 + uv1).xyz;
    vec3 near_color2 = texture2D(s_scene_ldr_color, v_texcoord0 + uv2).xyz;
    vec3 near_color3 = texture2D(s_scene_ldr_color, v_texcoord0 + uv3).xyz;
/*     vec3 near_color4 = texture2D(s_scene_ldr_color, v_texcoord0 + uv4).xyz;
    vec3 near_color5 = texture2D(s_scene_ldr_color, v_texcoord0 + uv5).xyz;
    vec3 near_color6 = texture2D(s_scene_ldr_color, v_texcoord0 + uv6).xyz;
    vec3 near_color7 = texture2D(s_scene_ldr_color, v_texcoord0 + uv7).xyz; 
 */
    vec3 box_min = min(current_color, min(near_color0, min(near_color1, min(near_color2, near_color3))));
    //box_min = min(box_min, min(near_color4, min(near_color5, min(near_color6, near_color7))));
    vec3 box_max = max(current_color, max(near_color0, max(near_color1, max(near_color2, near_color3))));
    //box_max = max(box_max, max(near_color4, max(near_color5, max(near_color6, near_color7))));
    if(u_first_frame.x == 0){
        prev_color = current_color; 
    }
    else{
        prev_color = clamp(prev_color, box_min, box_max); 
    }   
    float modulation_factor = 0.9;
    
    vec3 color = mix(current_color, prev_color, modulation_factor);
    gl_FragColor = vec4(color, 1.0);
}