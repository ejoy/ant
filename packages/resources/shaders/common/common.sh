#ifndef _COMMON_SH_
#define _COMMON_SH_
#include <bgfx_shader.sh>
uniform vec4 u_time;

#define u_current_time  u_time.x
#define u_delta_time    u_time.y

#endif //_COMMON_SH_