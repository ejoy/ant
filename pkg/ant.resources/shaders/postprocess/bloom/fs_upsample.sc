$input v_texcoord0
#include <bgfx_shader.sh>
#include "common/postprocess.sh"
#include "bloom.sh"

void main() {
    float lod = u_bloom_level;
    vec2 uv = v_texcoord0.xy;
#ifdef BLOOM_UPSAMPLE_QUALITY_HIGH
    vec3 c0, c1;
    c0  = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1, -1)).rgb;
    c0 += texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1, -1)).rgb;
    c0 += texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1,  1)).rgb;
    c0 += texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1,  1)).rgb;
    c0 += 4.0 * texture2DLod(s_scene_color, uv, lod).rgb;
    c1  = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1,  0)).rgb;
    c1 += texture2DLodOffset(s_scene_color, uv, lod, ivec2( 0, -1)).rgb;
    c1 += texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1,  0)).rgb;
    c1 += texture2DLodOffset(s_scene_color, uv, lod, ivec2( 0,  1)).rgb;
    gl_FragColor = vec4((c0 + 2.0 * c1) * (1.0 / 16.0), 1.0);
#else
    const vec2 halftexelsize = u_viewTexel.xy * 0.5;
    //sample 4 corner
    vec3 c;
    c  = texture2DLod(s_scene_color, uv - halftexelsize, lod).rgb;                              //left bottom
    c += texture2DLod(s_scene_color, uv + vec2(halftexelsize.x, -halftexelsize.y), lod).rgb;    //right bottom
    c += texture2DLod(s_scene_color, uv + halftexelsize, lod).rgb;                              //right top
    c += texture2DLod(s_scene_color, uv + vec2(-halftexelsize.x, halftexelsize.y), lod).rgb;      //left top
    gl_FragColor = vec4(c * 0.25, 1.0);
#endif
}