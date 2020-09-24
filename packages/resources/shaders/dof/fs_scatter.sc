$input v_color, v_particlecoord
#include <bgfx_shader.sh>
#include "dof/utils.sh"

/* accumulate color in the near/far blur buffers */
void main(void)
{
  /* Discard to avoid bleeding onto the next layer */
  vec2 edge = v_scatter_edge;
  if (int(gl_FragCoord.x) * edge.x + edge.y > 0) {
    discard;
  }

  /* Circle Dof */
  float dist = length(v_particlecoord);

  /* Outside of bokeh shape */
  if (dist > 1.0) {
    discard;
  }

  /* Regular Polygon Dof */
  if (u_bokeh_sides.x > 0.0) {
    /* Circle parametrization */
    float theta = atan(v_particlecoord.y, v_particlecoord.x) + u_bokeh_rotation;

    /* Optimized version of :
     * float denom = theta - (M_2PI / u_bokeh_sides) * floor((u_bokeh_sides * theta + M_PI) / M_2PI);
     * float r = cos(M_PI / u_bokeh_sides) / cos(denom); */
    float denom = theta - u_bokeh_sides.y * floor(u_bokeh_sides.z * theta + 0.5);
    float r = u_bokeh_sides.w / cos(denom);

    /* Divide circle radial coord by the shape radius for angle theta.
     * Giving us the new linear radius to the shape v_scatter_edge. */
    dist /= r;

    /* Outside of bokeh shape */
    if (dist > 1.0) {
      discard;
    }
  }

  gl_FragData[0] = v_color;

  /* Smooth the edges a bit. This effectively reduce the bokeh shape
   * but does fade out the undersampling artifacts. */
  float shape = smoothstep(1.0, min(0.999, v_scatter_smooth_fac), dist);

  gl_FragData[0] *= shape;

#  ifdef USE_ALPHA_DOF
  gl_FragData[0].a = v_scatter_weight * shape;
  gl_FragData[1] = gl_FragData.a;
#  endif
}
