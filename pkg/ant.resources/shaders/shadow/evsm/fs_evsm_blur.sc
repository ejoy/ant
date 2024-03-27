#include <bgfx_shader.sh>

#define SAMPLE_RADIUS   3

SAMPLER2DARRAY(s_input, 0);

uniform vec4 u_filter_param;

#define u_filter_layer      u_filter_param.x
#define u_filter_kernelsize u_filter_param.y
#define u_filter_sm_size    u_filter_param.z

vec4 fetch_texel(vec2 screenpos, int offset)
{
#if EVSM_BLUR_V
    screenpos.y = clamp(screenpos.y + (float)offset, 0, u_filter_sm_size);
#endif //EVSM_BLUR_V

#ifdef EVSM_BLUR_H
    screenpos.x = clamp(screenpos.x + (float)offset, 0, u_filter_sm_size);
#endif //EVSM_BLUR_H

    return texelFetch(s_input, ivec3(screenpos, u_filter_layer), 0);
}

void main()
{
    vec2 screenpos = gl_FragCoord.xy;
    const float radius = u_filter_kernelsize * 0.5;
    vec4 result = vec4_splat(0.0);
    UNROLL
    for(int i = -SAMPLE_RADIUS; i <= SAMPLE_RADIUS; ++i)
    {
        const float factor = saturate((radius + 0.5) - abs(i));
        result += fetch_texel(screenpos, i) * factor;
    }

    gl_FragColor = result / u_filter_kernelsize;
}