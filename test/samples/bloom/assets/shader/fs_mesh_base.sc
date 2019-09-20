//simple pbr 
$input v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7,v_worldPos,v_camPos
 
#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
 
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

SAMPLER2D(s_basecolor, 0);
SAMPLER2D(s_normal, 1); 
 
uniform vec4 u_params;
uniform vec4 u_diffuseColor;
uniform vec4 u_specularColor;
uniform vec4 u_tiling;
uniform vec4 camPos;

 
float GrayLumiance(vec3 color)
{
    return max(color.r,max(color.g,color.b));
    //return dot(color, vec3(0.2126, 0.7152, 0.0722));
} 

vec4 BaseColor(vec2 texcoord)
{
    return   ( texture2D(s_basecolor, texcoord ) );
}
 
void main()
{ 
    vec4 color = toLinear(BaseColor(v_texcoord0))*u_diffuseColor; 
    gl_FragData[0] = toGamma(color);
    float lum = GrayLumiance(color.rgb);
    if( lum>0.7 ) {
       gl_FragData[1] = vec4(color.rgb,1.0);  
    }else {
       gl_FragData[1] = vec4(0,0,0,1);
    }
    return;
}
  


 