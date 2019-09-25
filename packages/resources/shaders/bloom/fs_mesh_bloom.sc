//simple pbr 
$input v_texcoord0 
 
#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
 
SAMPLER2D(s_basecolor, 0);
SAMPLER2D(s_bloomcolor, 1);
uniform vec4  u_params; 

#define _MainTex  s_basecolor 
#define _BloomTex s_bloomcolor

#define LINEAR_COLORSPACE 1

#ifdef LINEAR_COLORSPACE 
#define ToLinear toLinear
#else 
#define ToLinear 
#endif

#ifdef LINEAR_COLORSPACE 
#define ToGamma toGamma 
#else 
#define ToGamma   
#endif   

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

void main()
{ 

    vec3  color = ToLinear(texture2D(_MainTex, v_texcoord0).rgb);      
    vec3  bloomColor = ToLinear(texture2D(_BloomTex, v_texcoord0).rgb);  //glow more clear
    float bloomScale = u_params.y;
    float exposure = u_params.z;
    if(u_params.x<1.0)
      color += bloomColor*bloomScale; 
    else
      color = color;
    color = ToneMappingSimple(color,exposure); 
    //color = ToneMapping(color,1.6,1);            
    color = ToGamma(color);    
    gl_FragData[0] = vec4(color,1.0);  
}






 