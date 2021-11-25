#ifndef _UVMOTION_SH_
#define _UVMOTION_SH_
#include "common/common.sh"

uniform vec4 u_uvmotion_speed;

vec2 uv_motion(vec2 uv)
{
#ifdef UV_MOTION
    float second = u_current_time;
    return uv + u_uvmotion_speed.xy * second;
#else //!UV_MOTION
    return uv;
#endif //UV_MOTION
}

#endif //_UVMOTION_SH_