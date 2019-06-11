$input  a_position, a_normal, a_texcoord0,a_tangent
$output v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7,v_worldPos,v_camPos

// for shadow
#include "mesh_shadow/vs_ext_shadowmaps_color_lighting_csm.sc"
   
#include "common/uniforms.sh"
#include <bgfx_shader.sh>
     
uniform vec4 u_tiling;	 
void main() 
{
    vec3 pos      = a_position;
	gl_Position   = mul(u_modelViewProj, vec4(pos, 1.0));

	vec4 worldpos = mul(u_model[0], vec4(pos, 1.0));
	v_worldPos    = worldpos.xyz; 
	v_camPos      = u_eyepos.xyz;  

	v_texcoord0  = a_texcoord0*u_tiling.xy;
	//v_texcoord0  = a_texcoord0;

	vec3 normal  = normalize(mul(u_model[0], vec4(a_normal.xyz, 0.0))).xyz;
	vec3 tangent = normalize(mul(u_model[0], vec4(a_tangent.xyz, 0.0))).xyz;   
	vec3 bitangent = cross(normal,tangent); 

    // use it oppostive face bump strongly ,avoid will be more flat but looks normally
	bitangent = -bitangent;  
 
	v_normal    = normal;
	v_tangent   = tangent;
	v_bitangent = bitangent;

 	mat3 tbn = transpose
	 		  ( mat3 (
 				normalize(tangent),
 			    normalize(bitangent),
  			    normalize(normal)
			   ) );
  
	// in tbn 
	v_lightdir = directional_lightdir[0].xyz;        //ms(dP,diP) invalid
    // v_lightdir[0] = 1.75;
    // v_lightdir[1] = 0.75;
    // v_lightdir[2] = 0; 

	v_lightdir 	= normalize( v_lightdir );   		
	v_viewdir 	= normalize( u_eyepos-worldpos).xyz;
	//v_lightdir  = mul(tbn,v_lightdir);
	//v_viewdir   = mul(tbn,v_viewdir);	

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