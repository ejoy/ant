$input v_texcoord0
#include <bgfx_shader.sh>

#include "common/postprocess.sh"

uniform vec4 u_sample_param;
#define u_sample_scale  u_sample_param.xy
#define u_texl_size     u_sample_param.zw
void main()
{
    vec2 tc = v_texcoord0 * u_sample_scale;
#ifdef MULTI_SAMPLE_BLOOM
    vec2 half_sample = u_texl_size * 0.5;

    vec4 sum = vec4_splat(0.0);
    // texture corner is bottom-left
    // 3 texel length, and 12 sub pixel
    // (-1,-1)   ( 0,-1)  ( 1,-1)
    //              *
    // (-1, 0) * ( 0, 0) * ( 1, 0)
    //              *
    // (-1, 1)   ( 0, 1)   ( 1, 1)

    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, tc);

    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, tc + vec2(-half_sample.x, 0.0));    // left
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, tc + vec2( half_sample.x, 0.0));    // right
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, tc + vec2(0.0, -half_sample.y));    // top
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, tc + vec2(0.0,  half_sample.y));    // bottom

    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + -u_texl_size.xy);                  // top-left
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + vec2(0.0, -u_texl_size.y));        // top
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + vec2( u_texl_size.x, -u_texl_size.y)); // right-top
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + vec2(-u_texl_size.x, 0.0));        // left
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + vec2( u_texl_size.x, 0.0));        // right
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + vec2(-u_texl_size.x,  u_texl_size.y)); // bottom-left
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + vec2( 0.0,  u_texl_size.y));       // bottom
    sum += (1.0/18.0)*texture2D(s_postprocess_input, tc + u_texl_size,xy);
    gl_FragColor = sum;
#else
    // use hardware linear interpolation
    gl_FragColor = texture2D(s_postprocess_input, tc);
#endif
    
}