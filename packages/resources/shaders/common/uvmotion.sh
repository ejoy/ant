#ifndef _UVMOTION_SH_
#define _UVMOTION_SH_
#include "common/common.sh"

uniform vec4 u_uvmotion_speed;

vec2 uv_motion(vec2 uv)
{
    float second = u_current_time / 1000.0;
    return uv + u_uvmotion_speed.xy * second;
}

#endif //_UVMOTION_SH_