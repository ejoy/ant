#ifndef _UVMOTION_SH_
#define _UVMOTION_SH_
#include "common/common.sh"

#define u_uvmotion_speed u_uvmotion.xy
#define u_uvmotion_tile u_uvmotion.zw

vec2 uv_motion(vec2 uv)
{
#ifdef UV_MOTION
    float second = u_current_time;
    return uv * u_uvmotion_tile + u_uvmotion_speed * second;
#else //!UV_MOTION
    return uv;
#endif //UV_MOTION
}

#endif //_UVMOTION_SH_