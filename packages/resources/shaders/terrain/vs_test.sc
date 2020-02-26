$input  a_position, a_normal
$output v_normal, v_positionWS

#include "common.sh"

#define v_distanceVS v_positionWS.w

void main()
{
	v_normal 	= normalize(mul(u_model[0], a_normal));
	vec4 pos 	= vec4(a_position, 1.0);

	v_positionWS = mul(u_model[0], pos);
	vec4 posVS 	 = mul(u_view, v_positionWS);
	v_distanceVS = posVS.z;

	gl_Position = mul(u_modelViewProj, pos);
}   

