$input v_texcoord0
#include <bgfx_shader.sh>
#include "common/postprocess.sh"
#include "postprocess/dof/utils.sh"

#define MERGE_THRESHOLD 4.0

SAMPLER2D(s_scatterBuffer,        0);

vec4 upsample_filter(sampler2D tex, vec2 uv, vec2 texelSize)
{
  /* TODO FIXME: Clamp the sample position
   * depending on the layer to avoid bleeding.
   * This is not really noticeable so leaving it as is for now. */

#  if 1 /* 9-tap bilinear upsampler (tent filter) */
  vec4 d = texelSize.xyxy * vec4(1, 1, -1, 0);

  vec4 s;
  s = texture2DLod(tex, uv - d.xy, 0.0);
  s += texture2DLod(tex, uv - d.wy, 0.0) * 2;
  s += texture2DLod(tex, uv - d.zy, 0.0);

  s += texture2DLod(tex, uv + d.zw, 0.0) * 2;
  s += texture2DLod(tex, uv, 0.0) * 4;
  s += texture2DLod(tex, uv + d.xw, 0.0) * 2;

  s += texture2DLod(tex, uv + d.zy, 0.0);
  s += texture2DLod(tex, uv + d.wy, 0.0) * 2;
  s += texture2DLod(tex, uv + d.xy, 0.0);

  return s * (1.0 / 16.0);
#  else
  /* 4-tap bilinear upsampler */
  vec4 d = texelSize.xyxy * vec4(-1, -1, +1, +1) * 0.5;

  vec4 s;
  s = texture2DLod(tex, uv + d.xy, 0.0);
  s += texture2DLod(tex, uv + d.zy, 0.0);
  s += texture2DLod(tex, uv + d.xw, 0.0);
  s += texture2DLod(tex, uv + d.zw, 0.0);

  return s * (1.0 / 4.0);
#  endif
}

/* Combine the Far and Near color buffers */
void main()
{
  /* Recompute Near / Far CoC per pixel */
  float depth = texture2DLod(s_mainview_depth, v_texcoord0, 0.0).r;
  float zdepth = linear_depth(depth);
  float coc_signed = calculate_coc(zdepth);
  float coc_far = max(-coc_signed, 0.0);
  float coc_near = max(coc_signed, 0.0);

  vec4 focus_col = texture2DLod(s_mainview, v_texcoord0, 0.0);

  vec2 texelSize = vec2(0.5, 1.0) / vec2(textureSize(s_scatterBuffer, 0));
  vec2 near_uv = v_texcoord0 * vec2(0.5, 1.0);
  vec2 far_uv = near_uv + vec2(0.5, 0.0);
  vec4 near_col = upsample_filter(s_scatterBuffer, near_uv, texelSize);
  vec4 far_col = upsample_filter(s_scatterBuffer, far_uv, texelSize);

  float far_w = far_col.a;
  float near_w = near_col.a;
  float focus_w = 1.0 - smoothstep(1.0, MERGE_THRESHOLD, abs(coc_signed));
  float inv_weight_sum = 1.0 / (near_w + focus_w + far_w);

  focus_col *= focus_w; /* Premul */

  gl_FragColor = (far_col + near_col + focus_col) * inv_weight_sum;
}
