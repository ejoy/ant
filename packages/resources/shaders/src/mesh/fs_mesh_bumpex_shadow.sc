$input v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7
 
#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
  
// for shadow 
#define SM_PCF 1    
#define SM_CSM 1
#include "mesh_shadow/fs_ext_shadowmaps_color_lighting.sh"
   
    
SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal, 1); 
uniform vec4 u_specularColor;
uniform vec4 u_specularLight;



void main()
{
	vec2 tc = vec2(v_texcoord0.x, v_texcoord0.y);

	vec4 ntexdata = texture2D(s_normal, tc);	
	vec3 normal = vec3(ntexdata.xy, 0.0);
	normal.xy = normal.xy * 2.0 - 1.0;
	normal.z = sqrt( (1.0- saturate(dot(normal.xy, normal.xy))) );
	float gloss = ntexdata.z;	
   
	// projection back 
	float pX = normal.x/(1.0 + normal.z);
	float pY = normal.y/(1.0 + normal.z);
	float denom = 2.0/(1.0 +pX*pX + pY*pY);
	normal.x = pX *denom;
	normal.y = pX *denom;  
	normal.z = denom -1.0;    
	              
    // not need now,, not in linear space 
	// vec4 basecolor = toLinear(texture2D(s_basecolor, tc));   
	vec4 basecolor = texture2D(s_basecolor, tc);
  
	vec4 lightcolor = directional_color[0] * directional_intensity[0].x;
	   
	float ambientMode   = ambient_mode.x;
	float ambientFactor = ambient_mode.y;   // Factor not use
	vec4  ambientColor  = calc_ambient_color( ambientMode, v_normal.y  ) ;
	ambientColor = ambientColor*basecolor;

	#include "mesh_shadow/fs_ext_shadowmaps_color_lighting_main.sh" 
	//visibility += 0.01f;	
	//gl_FragColor = saturate( (ambientColor + calc_lighting_BH(normal, v_lightdir, v_viewdir, lightcolor, basecolor, u_specularColor, gloss))*	visibility  );
  
	visibility -= 0.25f;	
	//visibility -= 0.5f;	
	gl_FragColor = saturate( (ambientColor + visibility * calc_lighting_BH(normal, v_lightdir, v_viewdir, lightcolor, 
																			basecolor, u_specularColor, gloss, u_specularLight.x)));
	// visibility += 0.5;
    // gl_FragColor *= visibility;
	// gl_FragColor = vec4(v_normal.xyz,1); //*0.5+0.5,1);  
}     

 