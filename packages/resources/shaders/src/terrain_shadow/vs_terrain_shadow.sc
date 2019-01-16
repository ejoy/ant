$input  a_position, a_normal, a_texcoord0 ,a_texcoord1
$output v_position, v_normal, v_texcoord0, v_texcoord1,   v_texcoord4, v_texcoord5, v_texcoord6, v_texcoord7

#include "../common/common.sh"

// for shadow
#include "mesh_shadow/vs_ext_shadowmaps_color_lighting_csm.sc"

void main()
{
	v_position = a_position.xyz;
	v_texcoord0 = a_texcoord0;
	v_texcoord1 = a_texcoord1;
	v_normal = normalize(a_normal);   					// modelviewproj *a_normal 
  
	gl_Position = mul(u_modelViewProj, vec4(v_position.xyz, 1.0));

	// for  shadow   
	#include "mesh_shadow/vs_ext_shadowmaps_color_lighting_csm_main.sc"

	/*
  	vec4 posOffset = vec4(a_position + v_normal.xyz * u_shadowMapOffset , 1.0);
	vec4 wpos = vec4(mul(u_model[0], posOffset).xyz, 1.0);    
	v_texcoord4 = mul(u_shadowMapMtx0, wpos);
	v_texcoord5 = mul(u_shadowMapMtx1, wpos);
	v_texcoord6 = mul(u_shadowMapMtx2, wpos);
	v_texcoord7 = mul(u_shadowMapMtx3, wpos);
    */
}   

