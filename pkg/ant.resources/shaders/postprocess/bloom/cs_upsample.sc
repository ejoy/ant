#include <bgfx_shader.sh>
#include <bgfx_compute.sh>

SAMPLER2D(s_color_input, 0);
IMAGE2D_WO(s_color_output, rgba16f, 1);

#include "common/utils.sh"
#include "postprocess/bloom/bloom.sh"

NUM_THREADS(16, 16, 1)
void main()
{
    const int lod = (int)u_bloom_level;
    const ivec2 uv_out = gl_GlobalInvocationID.xy;

    if (any(uv_out >= u_bloom_output_size))
        return;

    const vec2 uv = id2uv(gl_GlobalInvocationID.xy, u_bloom_output_size);

#ifdef BLOOM_UPSAMPLE_QUALITY_HIGH
    vec3 c0, c1;
    c0  = texture2DLodOffset(s_color_input, uv, lod, ivec2(-1, -1)).rgb;
    c0 += texture2DLodOffset(s_color_input, uv, lod, ivec2( 1, -1)).rgb;
    c0 += texture2DLodOffset(s_color_input, uv, lod, ivec2( 1,  1)).rgb;
    c0 += texture2DLodOffset(s_color_input, uv, lod, ivec2(-1,  1)).rgb;
    c0 += 4.0 * texture2DLod(s_color_input, uv, lod).rgb;
    c1  = texture2DLodOffset(s_color_input, uv, lod, ivec2(-1,  0)).rgb;
    c1 += texture2DLodOffset(s_color_input, uv, lod, ivec2( 0, -1)).rgb;
    c1 += texture2DLodOffset(s_color_input, uv, lod, ivec2( 1,  0)).rgb;
    c1 += texture2DLodOffset(s_color_input, uv, lod, ivec2( 0,  1)).rgb;
    vec4 finalresult = vec4((c0 + 2.0 * c1) * (1.0 / 16.0), 1.0);
#else
    const vec2 halftexelsize = u_bloom_output_texelsize * 0.5;

    //sample 4 corner
    vec3 c;
    c  = texture2DLod(s_color_input, uv - halftexelsize, lod).rgb;                              //left bottom
    c += texture2DLod(s_color_input, uv + vec2(halftexelsize.x, -halftexelsize.y), lod).rgb;    //right bottom
    c += texture2DLod(s_color_input, uv + halftexelsize, lod).rgb;                              //right top
    c += texture2DLod(s_color_input, uv + vec2(-halftexelsize.x, halftexelsize.y), lod).rgb;      //left top
    vec4 finalresult = vec4(c * 0.25, 1.0);
#endif

    imageStore(s_color_output, uv_out, finalresult);
}