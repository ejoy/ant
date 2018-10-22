$input  a_position, a_normal, a_texcoord0,a_tangent
$output v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent,  v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7

// for shadow
#include "mesh_shadow/vs_ext_shadowmaps_color_lighting_csm.sc"
   
#include "common/uniforms.sh"
#include <bgfx_shader.sh>
    
void main() 
{
   
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 worldpos = mul(u_model[0], vec4(pos, 1.0));
 
	v_texcoord0 = a_texcoord0;

	vec3 normal = normalize(mul(u_model[0], a_normal.xyz));
	vec3 tangent = normalize(mul(u_model[0], a_tangent.xyz));
	vec3 bitangent = (cross(normal,tangent))* a_tangent.w;
	//bitangent = -bitangent;
 
	v_normal = normal;
	v_tangent = tangent;
	v_bitangent = bitangent;
  
 	mat3 tbn = transpose(
			   mat3((tangent),
			   normalize(bitangent),
			   (normal)));
  
	v_lightdir 	= mul(directional_lightdir[0].xyz , tbn);
	v_viewdir 	= mul(normalize( u_eyepos - worldpos).xyz, tbn);	
	v_normal    = normal;
	 
	// for  shadow   
	#include "mesh_shadow/vs_ext_shadowmaps_color_lighting_csm_main.sc"
	/*
	vec4 posOffset = vec4(a_position + a_normal.xyz * u_shadowMapOffset, 1.0);
	vec4 wpos = vec4(mul(u_model[0], posOffset).xyz, 1.0);    
	v_texcoord1 = mul(u_shadowMapMtx0, wpos);
	v_texcoord2 = mul(u_shadowMapMtx1, wpos);
	v_texcoord3 = mul(u_shadowMapMtx2, wpos);
	v_texcoord4 = mul(u_shadowMapMtx3, wpos);
	*/
}