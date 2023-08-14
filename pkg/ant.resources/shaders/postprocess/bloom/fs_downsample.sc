$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/postprocess.sh"
#include "bloom.sh"

float max3(vec3 v){
    return max(v[0], max(v[1], v[2]));
}

void threshold(inout vec3 c) {
    // threshold everything below 1.0
    c = max(vec3_splat(0.0), c - u_bloom_threshold);
    // crush everything above 1
    float f = max3(c);
    c *= 1.0 / (1.0 + f * u_bloom_inv_highlight);
}

vec3 box4x4(vec3 s0, vec3 s1, vec3 s2, vec3 s3) {
    return (s0 + s1 + s2 + s3) * 0.25;
}

vec3 box4x4Reinhard(vec3 s0, vec3 s1, vec3 s2, vec3 s3) {
    float w0 = 1.0 / (1.0 + max3(s0));
    float w1 = 1.0 / (1.0 + max3(s1));
    float w2 = 1.0 / (1.0 + max3(s2));
    float w3 = 1.0 / (1.0 + max3(s3));
    return (s0 * w0 + s1 * w1 + s2 * w2 + s3 * w3) * (1.0 / (w0 + w1 + w2 + w3));
}

void main() {
    float lod = u_bloom_level;
    vec2 uv = v_texcoord0.xy;
#ifdef BLOOM_UPSAMPLE_QUALITY_HIGH
    vec3 c = texture2DLod(s_scene_color, uv, lod).rgb;

    vec3 lt = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1, -1)).rgb;
    vec3 rt = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1, -1)).rgb;
    vec3 rb = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1,  1)).rgb;
    vec3 lb = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1,  1)).rgb;

    vec3 lt2 = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-2, -2)).rgb;
    vec3 rt2 = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 2, -2)).rgb;
    vec3 rb2 = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 2,  2)).rgb;
    vec3 lb2 = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-2,  2)).rgb;

    vec3 l = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-2,  0)).rgb;
    vec3 t = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 0, -2)).rgb;
    vec3 r = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 2,  0)).rgb;
    vec3 b = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 0,  2)).rgb;  

    // five h4x4 boxes
    vec3 c0, c1;

    if (u_bloom_level <= 0.5) {
        if (u_bloom_threshold > 0.0) {
            // Threshold the first level blur
            threshold(c);
            threshold(lt);
            threshold(rt);
            threshold(rb);
            threshold(lb);
            threshold(lt2);
            threshold(rt2);
            threshold(rb2);
            threshold(lb2);
            threshold(l);
            threshold(t);
            threshold(r);
            threshold(b);
        }
        // Also apply fireflies (flickering) filtering
        c0  = box4x4Reinhard(lt, rt, rb, lb);
        c1  = box4x4Reinhard(c, l, t, lt2);
        c1 += box4x4Reinhard(c, r, t, rt2);
        c1 += box4x4Reinhard(c, r, b, rb2);
        c1 += box4x4Reinhard(c, l, b, lb2);
    } else {
        // common case
        c0  = box4x4(lt, rt, rb, lb);
        c1  = box4x4(c, l, t, lt2);
        c1 += box4x4(c, r, t, rt2);
        c1 += box4x4(c, r, b, rb2);
        c1 += box4x4(c, l, b, lb2);
    }

    // weighted average of the five boxes
    gl_FragColor = vec4(c0 * 0.5 + c1 * 0.125, 1.0);  
#else
    vec3 lt = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1, -1)).rgb;
    vec3 rt = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1, -1)).rgb;
    vec3 rb = texture2DLodOffset(s_scene_color, uv, lod, ivec2( 1,  1)).rgb;
    vec3 lb = texture2DLodOffset(s_scene_color, uv, lod, ivec2(-1,  1)).rgb;
    vec3 c;
    if (u_bloom_level <= 0.5) {
        if (u_bloom_threshold > 0.0) {
            threshold(lt);
            threshold(rt);
            threshold(rb);
            threshold(lb);
        }
        c  = box4x4Reinhard(lt, rt, rb, lb);
    } else {
        c  = box4x4(lt, rt, rb, lb);
    }
    gl_FragColor = vec4(c , 1.0); 
#endif
}