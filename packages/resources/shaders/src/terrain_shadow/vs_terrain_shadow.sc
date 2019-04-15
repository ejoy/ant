$input  a_position, a_normal, a_texcoord0 ,a_texcoord1
$output v_normal, v_texcoord0, v_texcoord1

#include "../common/common.sh"

void main()
{
	v_texcoord0 = a_texcoord0;
	v_texcoord1 = a_texcoord1;
	v_normal 	= normalize(mul(u_modelViewProj, a_normal));
  
	gl_Position = mul(u_modelViewProj, vec4(a_position, 1.0));
}   

