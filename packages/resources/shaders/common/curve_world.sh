#ifndef _CURVE_WORLD_SH_
#define _CURVE_WORLD_SH_

#include "common/camera.sh"

//ENABLE_CURVE_WORLD

#define CURVE_WORLD_TYPE_VIEW_SPHERE    1
#define CURVE_WORLD_TYPE_CYLINDER       2

uniform vec4 u_curveworld_param;

#if ENABLE_CURVE_WORLD == CURVE_WORLD_TYPE_VIEW_SPHERE
#define u_curveworld_flat_distance  u_curveworld_param.x
#define u_curveworld_base_distance  u_curveworld_param.y
#define u_curveworld_exp            u_curveworld_param.z
#define u_curveworld_amplification  u_curveworld_param.w
#endif //ENABLE_CURVE_WORLD == CURVE_WORLD_TYPE_VIEW_SPHERE

#if ENABLE_CURVE_WORLD == CURVE_WORLD_TYPE_CYLINDER
#define u_curveworld_cylinder_flat_distance u_curveworld_param.x
#define u_curveworld_cylinder_curve_rate    u_curveworld_param.y
#define u_curveworld_cylinder_distance      u_curveworld_param.z
#define u_curveworld_cylinder_max_range     u_curveworld_param.w
#endif //ENABLE_CURVE_WORLD == CURVE_WORLD_TYPE_CYLINDER

uniform vec4 u_curveworld_dir;

vec3 curve_world_offset(vec3 posWS)
{
#if ENABLE_CURVE_WORLD == CURVE_WORLD_TYPE_CYLINDER
    if (u_curveworld_cylinder_max_range > 0.0)
    {
        vec4 posVS = mul(u_view, vec4(posWS, 1.0));
        float dis = posVS.z-u_curveworld_cylinder_flat_distance;
        if (dis > 0){
            float radian = clamp((dis / u_curveworld_cylinder_distance) * PI * u_curveworld_cylinder_curve_rate, 0.0, u_curveworld_cylinder_max_range);
            float c = cos(radian), s = sin(radian);

            //TODO: rotation matrix create as rotate with x-axis in viewspace
            mat4 ct = mtxFromCols4(
                vec4(1.0, 0.0, 0.0, 0.0),
                vec4(0.0, c,   s,   0.0),
                vec4(0.0, -s,   c,   0.0),
                vec4(0.0, 0.0, 0.0, 1.0));

            // NOTE: we should add offset in VS and transform to WS, or it will faild depth test when compare to pre-depth pass's depth
            vec4 offsetVS = mul(ct, vec4(u_curveworld_dir.xyz*dis, 0.0));
            posVS.xyz += offsetVS.xyz;
            return mul(u_invView, posVS).xyz;
            //return posWS+offset;
        }
    }
    return posWS;

#endif //CURVE_WORLD_CYLINDER

#if ENABLE_CURVE_WORLD == CURVE_WORLD_TYPE_VIEW_SPHERE
    float dis = length(u_eyepos.xyz-posWS);
    vec3 dir = mul(u_invView, vec4(u_curveworld_dir.xyz, 0.0)).xyz;
    vec3 offset = u_curveworld_amplification*pow((dis-u_curveworld_flat_distance)/u_curveworld_base_distance, u_curveworld_exp)*dir;
    return posWS + offset;
#endif //CURVE_WORLD_VIEW_SPHERE
    return posWS;
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
