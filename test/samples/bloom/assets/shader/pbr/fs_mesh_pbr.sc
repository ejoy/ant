//simple pbr 
$input v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7,v_worldPos,v_camPos

#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
 
#include "common/pbr_protocol.sh"

#define LINEAR_COLORSPACE 1

#ifdef LINEAR_COLORSPACE 
#   define ToLinear toLinear
#else
#   define ToLinear 
#endif

#ifdef LINEAR_COLORSPACE 
#   define ToGamma toGamma 
#else 
#   define ToGamma
#endif
// brief solution for mobile 
// above 4 texture units, too expensive 
// step optimize: remove or combine texture 
// pbr  could have 3-4 textures
// usage: basemap,normalmap
//        metal map or metal params ,or combine map
//        cubemap
SAMPLER2D(s_basecolor, 0);
SAMPLER2D(s_normal, 1); 
SAMPLER2D(s_metallic, 2);   // extend this to contain rougheness,ao
                            // especially roughness

 
SAMPLERCUBE(s_texCube,3);
// irr could be removed to improve performance  
SAMPLERCUBE(s_texCubeIrr,4);
SAMPLER2D(s_brdfMap,5);
 
uniform vec4 u_params;
uniform vec4 u_diffuseColor;
uniform vec4 u_specularColor;
uniform vec4 u_tiling;
uniform vec4 camPos;

static float _BrightThreshold = 0.90f;
static float _Dielectric = 0.04f;


vec3 DirectLightRadiance(vec3 lightColor) 
{
    return lightColor;
}

vec3 PointLightRadiance(vec3 lightPos,vec3 lightColor,vec3 worldPos) 
{
    float distance = length(lightPos - worldPos);
    float attenuation = 1.0 / (distance * distance);
    vec3 radiance = lightColor * attenuation;
    return radiance;
}

 
vec3 DirectTerm( vec3 N, vec3 V, vec3 F0, float metallic, float roughness, vec3 albedo, vec3 worldPos, vec4 lightPos, vec3 lightColor ) 
{ 
    vec3 L,H;
    vec3 radiance;
    // extend light type here 
    if( lightPos.w > 0 ) {
        L = normalize( lightPos.xyz - worldPos );
        H = normalize( V + L);
        radiance = PointLightRadiance( lightPos.xyz,lightColor,worldPos);
    } else {
        L = normalize( lightPos.xyz );    
        H = normalize( V + L);
        radiance = DirectLightRadiance( lightColor );
    }

    float D  = DistributionGGX(N, H, roughness);
    float G  = GeometrySmith(N, V, L, roughness);      
    vec3  F  = fresnelSchlick(max(dot(H, V), 0.0), F0);


    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    vec3  nominator = D*G*F;

    float denominator = BrdfDenominatorStd(NdotV,NdotL);
    //float denominator = BrdfDenominatorOpt(NdotV,NdotL,roughness);
    vec3  specular = nominator / denominator;

    vec3 kS = F;
    vec3 kD = vec3_splat(1.0)- kS;
    kD *= 1.0 - metallic;

    vec3 color = kD*albedo/PI;

    color  = (color + specular)*radiance*NdotL;
    return color;        
}
 
vec3 AmbientTerm(vec3 N,vec3 V,vec3 R,vec3 F0,float metallic,float roughness,vec3 albedo,samplerCube s_texCubeIrr,samplerCube s_texCube)
{
    // F0 must keep source state
    vec3 eF = fresnelSchlickRoughness2(max(dot(N, V), 0.0), F0, roughness);
    vec3 ekS = eF;
    vec3 ekD = 1.0 - ekS;
    ekD *= 1.0 - metallic;	  

    float ndotv = max(dot(N,V),0.0);  
    // trick, approximate effect,not correct but enough good 
    // or optimize by SH, decrase consumption on mobie
    //vec3 irradiance  = ToLinear(textureCube(s_texCube, N).xyz);   
    vec3 irradiance  = ToLinear(textureCubeLod(s_texCube,N, 9).xyz);
    vec3 diffuse     =  ekD* irradiance * albedo;

    // prefilter map ,and do not need ambient brdf on mobie 
    float lod       = 0.1 + 4.0*(roughness);
    vec3  radiance  = ToLinear(textureCubeLod(s_texCube, R, lod).xyz);
    vec3  specular  = radiance*eF; 
    // if(textureSize(s_brdfMap,0).x>0) {
    //     vec2   envBRDF  = texture2D( s_brdfMap,vec2(ndotv,roughness)).xy;
    //     specular = radiance * (eF * envBRDF.x + envBRDF.y);  
    // }
    vec3 color = (diffuse + specular); 

    return color;
}

vec3 ToneMappingSimple(vec3 color,float exposure) 
{
   return vec3(1.0,1.0,1.0) - exp(-color * exposure);
}

vec3 ToneMapping(vec3 color,float exposure,float brightMax)
{
    float Yd = exposure * (exposure/brightMax + 1.0) / (exposure + 1.0);
    color *= Yd;
    return color;
}

float GrayLumiance(vec3 color)
{
    return max(color.x,max(color.y,color.z));
    //return dot(color, vec3(0.2126, 0.7152, 0.0722));
} 

vec4 BaseColor(vec2 texcoord)
{
    return   ( texture2D(s_basecolor, texcoord ) );
}
vec4 Phong(vec2 texcoord,vec3 worldPos,vec3 normal,vec4 lightColor,vec3 lightDir,vec3 camPos,float specPower)
{
    vec4  color =  ( texture2D(s_basecolor, texcoord ) );
    vec3  N = getWorldSpcaeNormalFromTexture( s_normal, texcoord, worldPos, normal  );
    vec3  V = normalize( camPos - worldPos ).xyz;
    vec3  L = normalize( lightDir ); 
    vec3  H = normalize( L+V ); 
    float NdotL = max(dot(N,L),0);
    float NdotH = max(dot(N,H),0);   
    vec4  diffColor = lightColor * color * NdotL;
    vec4  specColor = lightColor * pow(NdotH, specPower);
    color = diffColor + specColor;
    return color;
}

vec4 BlinPhong(vec2 texcoord,vec3 worldPos,vec3 normal,vec4 lightColor,vec3 lightDir,vec3 camPos,float specPower)
{
    vec4  color =  ( texture2D(s_basecolor, texcoord ) );
    vec3  N = getWorldSpcaeNormalFromTexture( s_normal, texcoord, worldPos, normal  );
    vec3  V = normalize( camPos - worldPos ).xyz;
    vec3  L = normalize( lightDir ); 
    vec3  H = normalize( L+V ); 
    vec3  R = reflect(-L,N);
    float NdotL = max(dot(N,L),0);
    float NdotH = max(dot(N,H),0);   
    vec4  diffColor = lightColor * color * NdotL;
    vec4  specColor = lightColor * pow(max(dot(V,R), 0.0), specPower);
    color = diffColor + specColor;
    return color;
}

vec4 Ambient(vec2 texcoord,vec4 lightColor,float intensity ) 
{
    vec4  color   =  ( texture2D(s_basecolor, texcoord ) );
    vec4  ambient = vec4(intensity,intensity,intensity,1.0);
    ambient *= lightColor*color;
    return ambient;
}

vec4 LightColor()
{
    return directional_color[0] * directional_intensity[0].x;  
}

vec3 DiffuseAndSpecularFromMetallic(vec3 albedo,float metallic) 
{
    vec3 F0 = vec3_splat(_Dielectric); 
    F0 = mix(F0, albedo, metallic);
    return F0;
}

#define SIMPLE_PBR 1

void main()
{ 
#ifndef SIMPLE_PBR
    
    vec4 color,lightColor;
    vec2 texcoord0 = v_texcoord0.xy*u_tiling.xy;
    lightColor = LightColor();
    color      = BlinPhong(texcoord0,v_worldPos,v_normal,lightColor,v_lightdir,v_camPos,128);
    //color     += Ambient(texcoord0,clamp(lightColor,0,1),0.2);
    //color      = BaseColor(texcoord0); 
    gl_FragData[0] = color;
    float lum = GrayLumiance(color.rgb);
    if( lum>_BrightThreshold ) {
       gl_FragData[1] = vec4(color.rgb,1.0);  
    }else
       gl_FragData[1] = vec4(color.rgb,1.0);  
    return;

#else 
     
   	vec2 texcoord      = vec2(v_texcoord0.x*u_tiling.x, v_texcoord0.y*u_tiling.y);
    vec4 lightColor    = LightColor();
    vec4 lightPos      = vec4(v_lightdir,0);     
    vec4 specularColor = u_specularColor;
     
   
    vec3  albedo    = ToLinear( texture2D(s_basecolor, texcoord ).rgb ); 
    vec3  N = getWorldSpcaeNormalFromTexture( s_normal, texcoord, v_worldPos, v_normal  );
    vec3  V = normalize( v_camPos - v_worldPos ).xyz;
    vec3  R = reflect(-V, N); 

    float roughness = u_params.w;
    float metallic  = u_params.z;                 
    if( u_params.y<1.0) {
       metallic  = texture2D(s_metallic, texcoord).r;
       metallic  = clamp(metallic,0.0,1.0);
    }
    // metallic = 1;    
    // roughness = 0.1;

    vec3 F0      = DiffuseAndSpecularFromMetallic(albedo,metallic);
    vec3 direct  = DirectTerm(N,V,F0,metallic,roughness,albedo,v_worldPos.xyz,lightPos,lightColor);  
    vec3 ambient = AmbientTerm(N,V,R,F0,metallic,roughness,albedo,s_texCubeIrr,s_texCube);
    vec3 color   = ambient + direct;
 
    color *= u_diffuseColor.xyz; 
    // shadow {
	// #include "mesh_shadow/fs_ext_shadowmaps_color_lighting_main.sh" 
	// visibility -= 0.25f;	
    // color = vec4(color*visibility ,1.0); 
    // }
    color = ToneMappingSimple(color,2.0f);  
    float lum = GrayLumiance(color);
    if( lum>_BrightThreshold ) {
        gl_FragData[1] = vec4(color,1.0);   
    } else {
        //gl_FragData[1] = vec4(color,1.0);   
    }
    color = ToGamma(color);        
    gl_FragData[0] = vec4(color,1.0);
#endif 
}
  


 