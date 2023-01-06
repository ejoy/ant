$input a_position, a_normal, a_texcoord0, a_tangent, a_bitangent	
$output v_texcoord0, v_lightdir, v_viewdir,v_normal	

#include <bgfx_shader.sh>	
#include "common/transform.sh"	// must define after bgfx_shader.sh	
#include "common/camera.sh"

void main()	
{	
    vec4 pos = vec4(a_position, 1);	
	gl_Position = mul(u_modelViewProj, pos);	
	vec4 worldpos = mul(u_model[0], pos);	
	mat3 tbn = calc_tbn(a_normal, a_tangent.xyz, a_bitangent, u_model[0]);	

	v_lightdir 	= mul(u_directional_lightdir.xyz , tbn);	
	v_viewdir 	= mul(normalize(u_eyepos.xyz - worldpos.xyz), tbn);	
	v_normal    = a_normal;	
	v_texcoord0 = a_texcoord0;	
}