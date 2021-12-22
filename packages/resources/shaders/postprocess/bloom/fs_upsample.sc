$input v_texcoord0
#include <bgfx_shader.sh>
#include "common/postprocess.sh"
#include "bloom.sh"

void main() {
    float lod = u_bloom_level;
    vec2 uv = v_texcoord0.xy;

// #if FILAMENT_QUALITY < FILAMENT_QUALITY_HIGH
//     highp vec4 d = vec4(materialParams.resolution.zw, -materialParams.resolution.zw) * 0.5;
//     vec3 c;
//     c  = texture2DLod(s_postprocess_input0, uv + d.zw, lod).rgb;
//     c += texture2DLod(s_postprocess_input0, uv + d.xw, lod).rgb;
//     c += texture2DLod(s_postprocess_input0, uv + d.xy, lod).rgb;
//     c += texture2DLod(s_postprocess_input0, uv + d.zy, lod).rgb;
//     postProcess.color.rgb = c * 0.25;
// #else
    vec3 c0, c1;
    c0  = texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2(-1, -1)).rgb;
    c0 += texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2( 1, -1)).rgb;
    c0 += texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2( 1,  1)).rgb;
    c0 += texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2(-1,  1)).rgb;
    c0 += 4.0 * texture2DLod(s_postprocess_input0, uv, lod).rgb;
    c1  = texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2(-1,  0)).rgb;
    c1 += texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2( 0, -1)).rgb;
    c1 += texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2( 1,  0)).rgb;
    c1 += texture2DLodOffset(s_postprocess_input0, uv, lod, ivec2( 0,  1)).rgb;
    gl_FragColor = vec4((c0 + 2.0 * c1) * (1.0 / 16.0), 1.0);
//#endif
}