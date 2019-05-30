$input  a_position, a_normal, a_texcoord0,a_tangent
$output v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7,v_worldPos,v_camPos

// for shadow
#include "mesh_shadow/vs_ext_shadowmaps_color_lighting_csm.sc"

#include <bgfx_shader.sh>   
#include "common/uniforms.sh"
     
void main() 
{
    vec3 pos = a_position;
	gl_Position = mul(u_modelViewProj, vec4(pos, 1.0));
	vec4 worldpos = mul(u_model[0], vec4(pos, 1.0));
	v_worldPos = worldpos.xyz; 

	v_camPos = u_eyepos.xyz;  
	//vec4 camPos = mul(vec4(0,0,0,1),u_view[0]);
	//v_camPos = camPos.xyz;
	// d3d & ogl error inversion in two shaderc version 
	// v_camPos = mul(u_view[0],vec4(0,0,0,1)).xyz;   

	v_texcoord0 = a_texcoord0;

	vec3 normal = normalize(mul(u_model[0], vec4(a_normal.xyz, 0.0))).xyz;
	vec3 tangent = normalize(mul(u_model[0], vec4(a_tangent.xyz, 0.0))).xyz;
    

 	//mat3 normalMatrix = transpose(inverse(mat3(u_model[0])));
    //vec3 tangent = normalize(normalMatrix * vec4(a_tangent.xyz, 0.0) );
    //vec3 normal  = normalize(normalMatrix * vec4(a_normal.xyz, 0.0));    
    	
	//tangent = normalize(tangent - dot(tangent,normal) * normal);
	vec3 bitangent = cross(normal,tangent); 

    // use it oppostive face bump strongly ,avoid will be more flat but looks normally
	bitangent = -bitangent;  
 
	v_normal = normal;
	v_tangent = tangent;
	v_bitangent = bitangent;

 	mat3 tbn =  transpose( mat3 (
 				normalize(tangent),
 			    normalize(bitangent),
  			    normalize(normal)
			   ) );
  
	// in tbn 
	v_lightdir 	= normalize(directional_lightdir[0].xyz);   //ms(dP,diP) invalid
	//v_lightdir = vec3(-0.9,-0.3,-0.3);     
	// v_lightdir = mul(directional_lightdir[0].xyz , tbn);
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