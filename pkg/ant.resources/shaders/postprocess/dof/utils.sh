#define v_scatter_weight        v_scatter_param.x
#define v_scatter_smooth_fac    v_scatter_param.y
#define v_scatter_edge          v_scatter_param.zw

uniform vec4 u_bokeh_param;
#define u_bokeh_rotation  u_bokeh_param.x
#define u_bokeh_ratio     u_bokeh_param.y
#define u_bokeh_maxsize   u_bokeh_param.z

uniform vec4 u_dof_param;
#define u_near u_dof_param.z
#define u_far  u_dof_param.w

#define u_dof_mul   u_dof_param.x /* distance * aperturesize * invsensorsize */
#define u_dof_bias  u_dof_param.y /* aperturesize * invsensorsize */

/* divide by sensor size to get the normalized size */
#define calculate_coc(zdepth) (u_dof_mul / zdepth - u_dof_bias)

// #define linear_depth(z) \
//     ((u_proj[3][3] == 0.0) ? \
//         (u_near * u_far) / (z * (u_near - u_far) + u_far) : \
//         z * (u_far - u_near) + u_near) /* Only true for camera view! */

#define linear_depth(z) (u_near * u_far) / (z * (u_near - u_far) + u_far)

#define weighted_sum(a, b, c, d, e) \
  (a * e.x + b * e.y + c * e.z + d * e.w) / max(1e-6, dot(e, vec4_splat(1.0)))

vec4 safe_color(vec4 c)
{
    /* Clamp to avoid black square artifacts if a pixel goes NaN. */
    return clamp(c, vec4_splat(0.0), vec4_splat(1e20)); /* 1e20 arbitrary. */
}