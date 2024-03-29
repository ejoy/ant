#include <bgfx_shader.sh>
#include "common/shadow/evsm_utils.sh"
SAMPLER2DARRAY(s_input, 0);

uniform vec4 u_filter_param;
#define u_filter_layer              u_filter_param.x
#define u_filter_positive_exponent  u_filter_param.z
#define u_filter_nagitive_exponent  u_filter_param.w
#define u_filter_exponents          u_filter_param.zw

void main()
{
    float depth = texelFetch(s_input, ivec3(gl_FragCoord.xy, u_filter_layer), 0).r;
    
#if EVSM_COMPONENT == 2
    float wd = warp_depth_positive(depth, u_filter_positive_exponent);
    gl_FragColor = vec4(wd, wd*wd, 0.0, 0.0); //RG16F/RG32F
#endif //

#if EVSM_COMPONENT == 4
    vec2 wd = warp_depth(depth, u_filter_exponents);
    gl_FragColor = vec4(wd, wd*wd);                 //RGBA16F/RGBA32F
#endif //
}