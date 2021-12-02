#ifndef _CURVE_WORLD_SH_
#define _CURVE_WORLD_SH_

#include "common/camera.sh"

//ENABLE_CURVE_WORLD

uniform vec4 u_curveworld_param;
#define u_curveworld_flat_distance  u_curveworld_param.x
#define u_curveworld_base_distance  u_curveworld_param.y
#define u_curveworld_exp            u_curveworld_param.z

uniform vec4 u_curveworld_dir;

// in world space
//vec3 offset = power((distanceof(worldpos, camerapos)- u_curveworld_flat_distance)/u_curveworld_base_distance, u_curveworld_exp) * u_curveworld_dir.xyz;
//posWS.xyz += offset;
vec3 curve_world_position(vec3 posWS)
{
    float dis = length(u_eyepos-posWS);
    vec3 offset = pow(dis-u_curveworld_flat_distance)/u_curveworld_base_distance, u_curveworld_exp) * u_curveworld_dir.xyz;
    return powWS.xyz + offset;
}

#endif //_CURVE_WORLD_SH_
