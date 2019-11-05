$input v_texcoord0
#include <bgfx_shader.sh>

#include "common/postprocess.sh"

void main()
{
    vec2 half_view_texel = u_viewTexel.xy * 0.5;

    vec4 sum = vec4_splat(0.0);
    // texture corner is bottom-left
    // 3 texel length, and 12 sub pixel
    // (-1,-1)   ( 0,-1)  ( 1,-1)
    //              *
    // (-1, 0) * ( 0, 0) * ( 1, 0)
    //              *
    // (-1, 1)   ( 0, 1)   ( 1, 1)

#ifdef MULTI_SAMPLE_BLOOM
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, v_texcoord0);

    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2(-half_view_texel.x, 0.0));    // left
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2( half_view_texel.x, 0.0));    // right
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2(0.0, -half_view_texel.y));    // top
    sum += (1.0/ 9.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2(0.0,  half_view_texel.y));    // bottom

    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + -u_viewTexel.xy);                     // top-left
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2(0.0, -u_viewTexel.y));        // top
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2( u_viewTexel.x, -u_viewTexel.y)); // right-top
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2(-u_viewTexel.x, 0.0));        // left
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2( u_viewTexel.x, 0.0));        // right
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2(-u_viewTexel.x,  u_viewTexel.y)); // bottom-left
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + vec2( 0.0,  u_viewTexel.y));       // bottom
    sum += (1.0/18.0)*texture2D(s_postprocess_input, v_texcoord0 + u_viewTexel,xy);
    gl_FragColor = sum;
#else
    // use hardware linear interpolation
    gl_FragColor = texture2D(s_postprocess_input, v_texcoord0);
#endif
    
}