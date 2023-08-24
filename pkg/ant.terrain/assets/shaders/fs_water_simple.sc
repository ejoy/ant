$input v_posCS v_distortUV v_noiseUV

#include <bgfx_shader.sh>

#include "common/common.sh"
#include "common/camera.sh"
#include "common/utils.sh"

SAMPLER2D(s_nosie,       0);
SAMPLER2D(s_distortion,  1);
SAMPLER2D(s_scene_depth, 2);

uniform vec4 u_gradient_shallow_color;
uniform vec4 u_gradient_deep_color;
uniform vec4 u_foam_color;

uniform vec4 u_distance_param;
#define u_depth_max_distance    u_distance_param.x
#define u_foam_min_distance     u_distance_param.y
#define u_foam_max_distance     u_distance_param.z

uniform vec4 u_surface_param;
#define u_noise_scroll          u_surface_param.xy
#define u_noise_cutoff          u_surface_param.z
#define u_distortion_scale      u_surface_param.w

#define SMOOTHSTEP_AA 0.01

vec4 normal_blending(vec4 top, vec4 bottom)
{
    vec3 color = lerp(bottom.rgb, top.rgb, top.a);
    float alpha = top.a + bottom.a * (1 - top.a);

    return vec4(color, alpha);
}

void main()
{
    vec2 uv = calc_normalize_fragcoord(gl_FragCoord.xy);
    float scene_depthVS = linear_depth(texture2D(s_scene_depth, uv.xy).r);
    float obj_depthVS = gl_FragCoord.w;
    float depth_diff = scene_depthVS - obj_depthVS;

    float water_depth_weight = saturate(depth_diff / u_depth_max_distance);
    vec4 water_color = lerp(u_gradient_shallow_color, u_gradient_deep_color, water_depth_weight);

    float foam_weight = saturate(depth_diff / u_foam_max_distance);

    float noise_cutoff = foam_weight * u_noise_cutoff;

    vec2 distort = (texture2D(s_distortion, v_distortUV).xy * 2.0 - 1.0) * u_distortion_scale;

    vec2 noiseUV = v_noiseUV + u_current_time * u_noise_scroll + distort;
    float noisevalue = texture2D(s_nosie, noiseUV).r;

    // Use smoothstep to ensure we get some anti-aliasing in the transition from foam to surface.
    // Uncomment the line below to see how it looks without AA.
    // float noise = noisevalue > noise_cutoff ? 1 : 0;
    float noise = smoothstep(noise_cutoff - SMOOTHSTEP_AA, noise_cutoff + SMOOTHSTEP_AA, noisevalue);

    vec4 nosie_color = u_foam_color;
    nosie_color.a *= noise;

    gl_FragColor = normal_blending(nosie_color, water_color);
}