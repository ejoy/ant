#ifdef SINGLE_COLOR
$input a_position
#else
$input a_position, a_color0
$output v_color0
#endif

#include <bgfx_shader.sh>

#include "common/constants.sh"

uniform vec4 u_camera_info;
#define u_near u_camera_info.x
#define u_far u_camera_info.y

vec4 do_cylinder_transform(vec4 posWS)
{
	vec4 posVS = mul(u_view, posWS);
    float radian = (posVS.z / u_far) * PI * 0.1;
    float c = cos(radian), s = sin(radian);

    mat4 ct = mtxFromCols4(
        vec4(1.0, 0.0, 0.0, 0.0),
        vec4(0.0, c,   s,   0.0),
        vec4(0.0, -s,   c,   0.0),
        vec4(0.0, 0.0, 0.0, 1.0));

    vec4 posCT = mul(ct, posVS);
	return mul(u_proj, posCT);
}

void main()
{
#ifdef CYLINDER_TRANSFORM
    vec4 posWS = mul(u_model[0], vec4(a_position, 1.0));
    gl_Position = do_cylinder_transform(posWS);
#else //!CYLINDER_TRANSFORM
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));
#endif //CYLINDER_TRANSFORM
#ifndef SINGLE_COLOR
    v_color0 = a_color0;
#endif 
}