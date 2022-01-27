#ifndef _COMMON_SH_
#define _COMMON_SH_
#include <bgfx_shader.sh>
uniform vec4 u_time;

#define u_current_time  u_time.x
#define u_delta_time    u_time.y

vec3 uvface2dir(vec2 uv, int face)
{
    switch (face){
    case 0:
        return vec3( 1.0, uv.y,-uv.x);
    case 1:
        return vec3(-1.0, uv.y, uv.x);
    case 2:
        return vec3( uv.x, 1.0,-uv.y);
    case 3:
        return vec3( uv.x,-1.0, uv.y);
    case 4:
        return vec3( uv.x, uv.y, 1.0);
    default:
        return vec3(-uv.x, uv.y,-1.0);
    }
}

vec2 dir2spherecoord(vec3 v)
{
	return vec2(
		0.5f + 0.5f * atan2(v.z, v.x) / M_PI,
		acos(v.y) / M_PI);
}


#endif //_COMMON_SH_