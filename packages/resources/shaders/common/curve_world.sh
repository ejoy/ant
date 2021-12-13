#ifndef _CURVE_WORLD_SH_
#define _CURVE_WORLD_SH_

#include "common/camera.sh"

//ENABLE_CURVE_WORLD

uniform vec4 u_curveworld_param;
#define u_curveworld_flat_distance  u_curveworld_param.x
#define u_curveworld_base_distance  u_curveworld_param.y
#define u_curveworld_exp            u_curveworld_param.z
#define u_curveworld_amplification  u_curveworld_param.w

uniform vec4 u_curveworld_dir;

// in world space
// flat, base, exp, amp
// dirWS = mul(u_invView, dirVS)
// dis = length(u_eyepos-posWS);
// offset = (amp*((dis-flat)/base)^exp) * dirWS
//vec3 offset = power((distanceof(worldpos, camerapos)- u_curveworld_flat_distance)/u_curveworld_base_distance, u_curveworld_exp) * u_curveworld_dir.xyz;
//posWS.xyz += offset;
vec3 curve_world_offset(vec3 posWS)
{
    float dis = length(u_eyepos.xyz-posWS);
    vec3 dir = mul(u_invView, vec4(u_curveworld_dir.xyz, 0.0)).xyz;
    vec3 offset = u_curveworld_amplification*pow((dis-u_curveworld_flat_distance)/u_curveworld_base_distance, u_curveworld_exp)*dir;
    return posWS + offset;
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
