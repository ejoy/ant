#include "common/postprocess.sh"
#include "dof/utils.sh"

#define out_nearColor   gl_FragColor[0]
#define out_farColor    gl_FragColor[1]
#define out_cocData     gl_FragColor[2]

/* Downsample the color buffer to half resolution.
 * Weight color samples by
 * Compute maximum CoC for near and far blur. */
void main(void)
{
  ivec4 uvs = ivec4(gl_FragCoord.xyxy) * 2 + ivec4(0, 0, 1, 1);

  /* custom downsampling */
  vec4 color1 = safe_color(texelFetch(s_mainview, uvs.xy, 0));
  vec4 color2 = safe_color(texelFetch(s_mainview, uvs.zw, 0));
  vec4 color3 = safe_color(texelFetch(s_mainview, uvs.zy, 0));
  vec4 color4 = safe_color(texelFetch(s_mainview, uvs.xw, 0));

  /* Leverage SIMD by combining 4 depth samples into a vec4 */
  vec4 depth = vec4(
            texelFetch(s_mainview_depth, uvs.xy, 0).r,
            texelFetch(s_mainview_depth, uvs.zw, 0).r,
            texelFetch(s_mainview_depth, uvs.zy, 0).r,
            texelFetch(s_mainview_depth, uvs.xw, 0).r);

  vec4 zdepth = linear_depth(depth);

  /* Compute signed CoC for each depth samples */
  vec4 coc_near = calculate_coc(zdepth);
  vec4 coc_far = -coc_near;

  out_cocData.x = max(max_v4(coc_near), 0.0);
  out_cocData.y = max(max_v4(coc_far), 0.0);

  /* now we need to write the near-far fields premultiplied by the coc
   * also use bilateral weighting by each coc values to avoid bleeding. */
  vec4 near_weights = step(THRESHOLD, coc_near) * clamp(1.0 - abs(out_cocData.x - coc_near), 0.0, 1.0);
  vec4 far_weights = step(THRESHOLD, coc_far) * clamp(1.0 - abs(out_cocData.y - coc_far), 0.0, 1.0);

#  ifdef USE_ALPHA_DOF
  /* Premult */
  color1.rgb *= color1.a;
  color2.rgb *= color2.a;
  color3.rgb *= color3.a;
  color4.rgb *= color4.a;
#  endif

  /* now write output to weighted buffers. */
  out_nearColor = weighted_sum(color1, color2, color3, color4, near_weights);
  out_farColor  = weighted_sum(color1, color2, color3, color4, far_weights);
}