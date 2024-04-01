#include <bgfx_shader.sh>

#define EVSM_FILTER_TYPE_UNIFORM    1
#define EVSM_FILTER_TYPE_GAUSSIAN   2

#ifndef EVSM_FILTER_TYPE
#define EVSM_FILTER_TYPE EVSM_FILTER_TYPE_UNIFORM
#endif //!EVSM_FILTER_TYPE

#ifndef EVSM_SAMPLE_RADIUS
#define EVSM_SAMPLE_RADIUS 2
#endif //!EVSM_SAMPLE_RADIUS

#if EVSM_FILTER_TYPE == EVSM_FILTER_TYPE_GAUSSIAN
#   if EVSM_SAMPLE_RADIUS == 1
// 1 2 1
static const float GAUSSIAN_WEIGHTS[3] = {0.25, 0.5, 0.5};
#   elif EVSM_SAMPLE_RADIUS == 2
// 1 4 6 4 1
static const float GAUSSIAN_WEIGHTS[5] = {1.0/16, 4.0/16, 6.0/16, 4.0/16, 1.0/16};
#   elif EVSM_SAMPLE_RADIUS == 3
// 1 3 7 9 7 3 1
static const float GAUSSIAN_WEIGHTS[7] = {1.0/21, 3.0/21, 7.0/21, 9.0/21, 7.0/21, 3.0/21, 1.0/21};
#   else
//#   error Not support EVSM_SAMPLE_RADIUS
#   endif 

SAMPLER2DARRAY(s_input, 0);

uniform vec4 u_filter_param;

#define u_filter_layer      u_filter_param.x
#define u_filter_sm_size    u_filter_param.y

vec4 fetch_texel(vec2 screenpos, int offset)
{
#ifdef EVSM_BLUR_V
    screenpos.y = clamp(screenpos.y + (float)offset, 0, u_filter_sm_size);
#endif //EVSM_BLUR_V

#ifdef EVSM_BLUR_H
    screenpos.x = clamp(screenpos.x + (float)offset, 0, u_filter_sm_size);
#endif //EVSM_BLUR_H

    return texelFetch(s_input, ivec3(screenpos, u_filter_layer), 0);
}

#endif //EVSM_FILTER_TYPE == EVSM_FILTER_TYPE_GAUSSIAN

void main()
{
    vec2 screenpos = gl_FragCoord.xy;
    vec4 result = vec4_splat(0.0);
#if EVSM_FILTER_TYPE == EVSM_FILTER_TYPE_UNIFORM
    UNROLL
    for(int i = -EVSM_SAMPLE_RADIUS; i <= EVSM_SAMPLE_RADIUS; ++i)
    {
        result += fetch_texel(screenpos, i);
    }

    const int count = EVSM_SAMPLE_RADIUS*2 + 1;

    gl_FragColor = result / count;

#elif EVSM_FILTER_TYPE == EVSM_FILTER_TYPE_GAUSSIAN
    for(int i = -EVSM_SAMPLE_RADIUS; i <= EVSM_SAMPLE_RADIUS; ++i)
    {
        const int idx = i + EVSM_SAMPLE_RADIUS;
        const float w = GAUSSIAN_WEIGHTS[idx];
        result += fetch_texel(screenpos, i) * w;
    }
    gl_FragColor = result;
#else
#error EVSM_FILTER_TYPE is not defined
#endif //
}