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
vec3 curve_world_offset(vec3 posWS)
{
    float dis = length(u_eyepos.xyz-posWS);
    vec3 offset = pow(dis-u_curveworld_flat_distance)/u_curveworld_base_distance, u_curveworld_exp) * u_curveworld_dir.xyz;
    return powWS + offset;
}

// vec4 do_cylinder_transform(vec4 posWS)
// {
// 	vec4 posVS = mul(u_view, posWS);
//     float radian = (posVS.z / u_far) * PI * 0.1;
//     float c = cos(radian), s = sin(radian);

//     mat4 ct = mtxFromCols4(
//         vec4(1.0, 0.0, 0.0, 0.0),
//         vec4(0.0, c,   s,   0.0),
//         vec4(0.0, -s,   c,   0.0),
//         vec4(0.0, 0.0, 0.0, 1.0));

//     vec4 posCT = mul(ct, posVS);
// 	return mul(u_proj, posCT);
// }

#endif //_CURVE_WORLD_SH_
