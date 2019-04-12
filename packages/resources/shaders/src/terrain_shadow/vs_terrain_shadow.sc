$input  a_position, a_normal, a_texcoord0 ,a_texcoord1
$output v_normal, v_texcoord0, v_texcoord1

#include "../common/common.sh"

void main()
{
	v_texcoord0 = a_texcoord0;
	v_texcoord1 = a_texcoord1;
	v_normal = normalize(a_normal);   					// modelviewproj *a_normal 
  
	gl_Position = mul(u_modelViewProj, vec4(v_position.xyz, 1.0));
}   

