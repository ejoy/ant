$input v_texcoord0
#include <bgfx_shader.sh>
#include "common/postprocess.sh"
#include "bloom.sh"

void main() {
    float lod = u_bloom_level;
    vec2 uv = v_texcoord0.xy;

    const vec2 halftexelsize = u_viewTexel.xy * 0.5;
    //sample 4 corner
    vec3 c;
    c  = texture2DLod(s_scene_color, uv - halftexelsize, lod).rgb;                              //left bottom
    c += texture2DLod(s_scene_color, uv + vec2(halftexelsize.x, -halftexelsize.y), lod).rgb;    //right bottom
    c += texture2DLod(s_scene_color, uv + halftexelsize, lod).rgb;                              //right top
    c += texture2DLod(s_scene_color, uv + vec2(-halftexelsize.x, halftexelsize.y), lod).rgb;      //left top
    gl_FragColor = vec4(c * 0.25, 1.0);

}