$input v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7,v_worldPos,v_camPos
 
#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
 
#include "pbr_protocol.sh"    
        
// for shadow 
#define SM_PCF 1     
#define SM_CSM 1 
#include "mesh_shadow/fs_ext_shadowmaps_color_lighting.sh"
 
// brief solution for mobile 
// above 4 texture units, too expensive 
// step optimize: remove or combine texture 
// pbr  could have 3-4 textures
// usage: basemap,normalmap
//        metal map or metal params ,or combine map
//        cubemap
SAMPLER2D(s_basecolor, 0);
SAMPLER2D(s_normal, 1); 
SAMPLER2D(s_metallic, 2);
//SAMPLER2D(s_roughness, 10);
 
SAMPLERCUBE(s_texCube,3);
// irr could be removed to improve performance  
SAMPLERCUBE(s_texCubeIrr,9);

 
uniform vec4 u_params;
uniform vec4 u_diffuseColor;
uniform vec4 u_specularColor;
uniform vec4 camPos;

//utils
 

//app
 
vec3 directlight_radiance(vec3 lightColor) 
{
    return lightColor;
}

vec3 pointlight_radiance(vec3 lightPos,vec3 lightColor,vec3 worldPos) 
{
    float distance = length(lightPos - worldPos);
    float attenuation = 1.0 / (distance * distance);
    vec3 radiance = lightColor * attenuation;
    return radiance;
}
 
vec3 direct_term( vec3 N, vec3 V, vec3 F0, float metallic, float roughness, vec3 albedo, vec3 worldPos, vec4 lightPos,vec3 lightColor ) 
{ 
        vec3 L,H;
        vec3 radiance;
        // extend light type here 
        if( lightPos.w > 0 ) {
           L = normalize( lightPos.xyz - worldPos );                   
           H = normalize( V + L);
           radiance = pointlight_radiance( lightPos.xyz,lightColor,worldPos);
        } else {
           L = normalize( lightPos.xyz );    
           H = normalize( V + L);
           radiance = directlight_radiance( lightColor );
        }

        float D  = DistributionGGX(N, H, roughness);
        float G  = GeometrySmith(N, V, L, roughness);      
        vec3  F  = fresnelSchlick(max(dot(H, V), 0.0), F0);
        //vec3  F  = fresnelSchlickRoughness(max(dot(H, V), 0.0), F0,roughness);

        float NdotL = max(dot(N, L), 0.0);
        float NdotV = max(dot(N, V), 0.0);
        vec3  nominator = D*G*F;

        float denominator = BrdfDenominatorStd(NdotV,NdotL);
        //float denominator = BrdfDenominatorOpt(NdotV,NdotL,roughness);
        vec3  specular = nominator / denominator;

        vec3 kS = F;
        vec3 kD = vec3_c(1.0)- kS;
        kD *= 1.0 - metallic;

        vec3 color = kD*albedo/PI;

        color  = (color + specular)*radiance*NdotL;
        return color;        
}

vec3 ambient_term(vec3 N,vec3 V,vec3 R,vec3 F0,float metallic,float roughness,vec3 albedo,samplerCube s_texCubeIrr,samplerCube s_texCube)
{
    // F0 must keep source state
    vec3 eF = fresnelSchlickRoughness(max(dot(N, V), 0.0), F0, roughness);

    vec3 ekS = eF;
    vec3 ekD = 1.0 - ekS;
    ekD *= 1.0 - metallic;	  

    // trick, approximate effect,not correct but enough good 
    // or optimize by SH, decrase consumption on mobie
    // vec3 irradiance  = toLinear(textureCube(s_texCubeIrr, N).xyz);
    vec3 irradiance  = toLinear(textureCubeLod(s_texCube,N, 12).xyz);
    vec3 diffuse    =  ekD* irradiance * albedo;

    // prefilter map ,and do not need ambient brdf on mobie 
    float lod       = 0.1 + 5.0*(roughness);
    vec3  radiance  = toLinear(textureCubeLod(s_texCube, R, lod).xyz);
    vec3  specular  = radiance*eF; 

    vec3 color = (diffuse + specular); 
    return color;
}

 
void main()
{ 
    vec4 lightColor    = directional_color[0] * directional_intensity[0].x;
    vec4 lightPos      = vec4(v_lightdir,0);    // default directional
    vec4 specularColor = u_specularColor;
     
	vec2 TC = vec2(v_texcoord0.x, v_texcoord0.y);
   
    vec3  albedo    = toLinear( texture2D(s_basecolor, TC ).rgb ); 
    float metallic  = u_params.z;    // from uniform 
    float roughness = u_params.w;

    if( u_params.y<1.0) {
       metallic  = texture2D(s_metallic, TC).r;
       metallic =  clamp(metallic*1.2,0.0,1.0);
    }
     
    //roughness = (0.777 - roughness)*0.5; //  keep more rougheness
    //roughness = (1-roughness)*0.5;        // tex 
 
    //add diffuse color for setting 
    //albedo *= u_diffuseColor.xyz*(1.0-u_params.z);  

    vec3 N = getNormalFromMap( s_normal, TC, v_worldPos, v_normal  );
    vec3 V = normalize( v_camPos - v_worldPos ).xyz;
    vec3 R = reflect(-V, N); 
   
    vec3 F0; 
    if( u_params.x < 1.0 ) {    // keep simple when use, only have one flow 
        F0 = vec3_c(0.04); 
        F0 = mix(F0, albedo, metallic);
    } else  { //specular flow 
        F0 = specularColor.xyz*vec3_c(metallic);
    }

    // direct     
    vec3 direct = vec3_c(0.0);
    //vec3 direct_term( vec3 N, vec3 V, vec3 F0, float metallic, float roughness, vec3 albedo, vec3 worldPos, vec4 lightPos,vec3 lightColor ) 
    direct = direct_term(N,V,F0,metallic,roughness,albedo,v_worldPos.xyz,lightPos,lightColor);
   
    // ambient 
    vec3 ambient = vec3_c(0);  
    //vec3 ambient_term(vec3 N,vec3 V,vec3 R,vec3 F0,float metallic,float roughness,vec3 albedo,samplerCube s_texCubeIrr,samplerCube s_texCube)
    ambient = ambient_term(N,V,R,F0,metallic,roughness,albedo,s_texCubeIrr,s_texCube);

    vec3 color = ambient + direct;

    color *= u_diffuseColor.xyz; 

	//#include "mesh_shadow/fs_ext_shadowmaps_color_lighting_main.sh" 
	//visibility -= 0.25f;	
    //color = vec4(color*visibility ,1.0); 

    color = toneMapping(color); 

	// Gamma correction.
    color = toGamma(color);

    gl_FragColor = vec4(color,1.0); 
    
}



 