#include <bgfx_shader.sh>
#include "common/shadow/evsm_utils.sh"
SAMPLER2DARRAY(s_input, 0);

uniform vec4 u_filter_param;
#define u_filter_layer      u_filter_param.x
#define u_filter_exponents  u_filter_param.zw

void main()
{
    float depth = texelFetch(s_input, ivec3(gl_FragCoord.xy, u_filter_layer), 0).r;
    vec2 wd = warp_depth(depth, u_filter_exponents);
    gl_FragColor = vec4(wd, wd*wd);
}