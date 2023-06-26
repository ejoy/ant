#ifndef _COMMON_SH_
#define _COMMON_SH_
#include <bgfx_shader.sh>

#ifndef ORIGIN_BOTTOM_LEFT
#define ORIGIN_BOTTOM_LEFT 0
#endif //ORIGIN_BOTTOM_LEFT

#ifndef HOMOGENEOUS_DEPTH
#define HOMOGENEOUS_DEPTH 0
#endif //HOMOGENEOUS_DEPTH

uniform vec4 u_time;

#define u_current_time  u_time.x
#define u_delta_time    u_time.y

uniform vec4 u_jitter;
#endif //_COMMON_SH_