#ifndef _SSAO_DEF_SC_
#define _SSAO_DEF_SC_

uniform vec4 u_ssao_param;
#define u_ssao_visiblity_power          u_ssao_param.x
#define u_ssao_angle_inc_cos            u_ssao_param.y
#define u_ssao_angle_inc_sin            u_ssao_param.z
#define u_ssao_edge_distance            u_ssao_param.w

uniform vec4 u_ssao_param2;
#define u_ssao_sample_count             u_ssao_param2.x
#define u_ssao_inv_sample_count         u_ssao_param2.y
#define u_ssao_intensity                u_ssao_param2.z
#define u_ssao_bias                     u_ssao_param2.w

uniform vec4 u_ssao_param3;
#define u_ssao_inv_radius_squared               u_ssao_param3.x
#define u_ssao_min_horizon_angle_sine_squared   u_ssao_param3.y
#define u_ssao_peak2                            u_ssao_param3.z
#define u_ssao_spiral_turns                     u_ssao_param3.w

uniform vec4 u_ssao_param4;
#define u_ssao_texelsize                        u_ssao_param4.xy
#define u_ssao_max_level                        u_ssao_param4.z
#define u_ssao_projection_scale_radius          u_ssao_param4.w

// ssct
uniform vec4 u_ssct_param;
#define u_ssct_lightdirVS                       u_ssct_param.xyz
#define u_ssct_projection_scale                 u_ssct_param.w

uniform vec4 u_ssct_param2;
#define u_ssct_cone_angle_tangeant              u_ssct_param2.x
#define u_ssct_intensity                        u_ssct_param2.y
#define u_ssct_contact_distance_max_inv         u_ssct_param2.z
#define u_ssct_shadow_distance                  u_ssct_param2.w

uniform vec4 u_ssct_param3;
#define u_ssct_sample_count                     u_ssct_param3.x
#define u_ssct_ray_count                        u_ssct_param3.y
#define u_ssct_depth_bias                       u_ssct_param3.z
#define u_ssct_slope_scaled_depth_bias          u_ssct_param3.w

uniform mat4 u_ssct_screen_from_view_mat;

#endif //_SSAO_DEF_SC_