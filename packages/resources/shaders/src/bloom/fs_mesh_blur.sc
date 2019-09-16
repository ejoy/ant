//simple pbr 
$input v_texcoord0 
 
#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
 
SAMPLER2D(s_basecolor, 0);
uniform vec4  u_params; 
uniform vec4  u_blur;

#define _MainTex s_basecolor 

//simple blur ，simple test，no control params 
//   blur iters = 2,blur_strength = 0.75, seems good
//   blur iters = 1,blur_strength = 0.5, seems good
//#define _SIMPLE_ 1    
//#define _DIRECT_ 1
#define _OPT_ 1

static const float sWeights[7] = { 
     0.2270270270,
     0.1945945946,
     0.1216216216,
     0.0540540541,
     0.0540540541,
     0.0162162162,
     0.0162162162,
};

static float offset[3] = { 0.0, 1.3846153846, 3.2307692308 };
static float weight[3] = { 0.2270270270, 0.3162162162, 0.0702702703 };

static const float mWeights[4] = {
     0.415, 0.262, 0.048, 0.003  //-> 0.172,0.109,0.020,0.001 
};

static const float xWeights[5] = {
     0.054489, 0.244201, 0.402620, 0.244201, 0.054489
};

static const float hWeights[13] =
{
	0.002216,	0.008764,	0.026995,
	0.064759,	0.120985,	0.176033,
	0.199471,	0.176033,	0.120985,
	0.064759,	0.026995,	0.008764,
	0.002216
};

//EXP(-1/2(x-u)T*E(x-u))
// x = 1.0 / (sqrt(2.0 * pi) * sigma);
// y = exp(-0.5 / (sigma * sigma));
// z = x*y

//standard
float Gaussian (float x, float sigma)
{
	return (1.0 / sqrt(2.0 * 3.141592) * sigma) * exp(-((x * x) / (2.0 * sigma*sigma)));	
}
float GaussianD1( float x, float y, float sigma)
{
	float g = 1.0f / sqrt( 2.0f * 3.141592 * sigma * sigma );
	g *= exp( -( x * x + y * y ) / ( 2 * sigma * sigma));
	return g;
}
// variant
float GaussianD2(in float x, in float sigma) {
     return 0.39894 * exp( -0.5 * x * x/( sigma * sigma))/sigma;
     //return 0.39894 * exp( -0.5* x * x/( sigma * sigma))/sigma;
     //return 0.24197 * exp( -0.5* x * x/( sigma * sigma))/sigma;
}

// vec3 GaussianBlur(vec2 centreUV, vec2 halfPixelOffset, vec2 pixelOffset )                                                                           
// {                                                                                                                                                                    
//     vec3 colOut = vec3( 0, 0, 0 );                                                                                                                                   
                                                                                                                                                                     
//     ////////////////////////////////////////////////;
//     // Kernel width 7 x 7
//     //
//     const int stepCount = 2;
//     //
//     const float Weights[stepCount] ={
//        0.44908,
//        0.05092
//     };
//     const float Offsets[stepCount] ={
//        0.53805,
//        2.06278
//     };
//     ////////////////////////////////////////////////;

//     for( int i = 0; i < stepCount; i++ )                                                                                                                             
//     {                                                                                                                                                                
//         vec2 texCoordOffset = Offsets[i] * pixelOffset;                                                                                                           
//         vec3 col = texture2D( _MainTex, centreUV + texCoordOffset ).xyz + 
//                    texture2D( _MainTex, centreUV – texCoordOffset ).xyz;                                                
//         colOut += Weights[i] * col;                                                                                                                               
//     }                                                                                                                                                                

//     return colOut;
// }                       



#define Weights sWeights 
#define Itertal 5

void main()
{ 
#ifdef _SIMPLE_     
    // simple one pass 
    float  spread = u_params.y;
    float  direction  = u_params.x;
    float  blurStrength = u_blur.y;
    vec2   pixelSize  = u_params.zw; 
    vec2   dir   = vec2(!direction,direction);
    vec2   ofs   = dir *pixelSize*spread;
    vec3   color = texture2D(_MainTex,v_texcoord0.xy).rgb*Weights[0];
    for(int i = 1; i < Itertal; ++i)  {
            color  += texture2D(_MainTex, v_texcoord0 + i*ofs).rgb * Weights[i]*blurStrength;
            color  += texture2D(_MainTex, v_texcoord0 - i*ofs).rgb * Weights[i]*blurStrength;            
    }
    if(gl_FragCoord.x>textureSize(_MainTex,0).x*3/4 && gl_FragCoord.y<textureSize(_MainTex,0).y/4)
       color = vec3(0,1,0);
    gl_FragData[0] = vec4(color,1.0);   
#endif

#ifdef _DIRECT_

     //----------------------
     //float spreadForPass = (1.0f + (iter * 0.25f)) * spread;
	//float widthOverHeight = (1.0f * fb.width) / (1.0f * fb.height);
	//float oneOverBaseSize = 1.0f / 512.0f;

#endif


#ifdef _OPT_
      
     /*
     A = 1;
     x0 = 0; y0 = 0;
     sigma_X = 1;
     sigma_Y = 2;
     for theta = 0:pi/100:pi
     a = cos(theta)^2/(2*sigma_X^2) + sin(theta)^2/(2*sigma_Y^2);
     b = -sin(2*theta)/(4*sigma_X^2) + sin(2*theta)/(4*sigma_Y^2);
     c = sin(theta)^2/(2*sigma_X^2) + cos(theta)^2/(2*sigma_Y^2);
     Z = A*exp( - (a*(X-x0).^2 + 2*b*(X-x0).*(Y-y0) + c*(Y-y0).^2));
     waitforbuttonpress
     */
     //Gaussian.x = 1.0 / (sqrt(2.0 * pi) * sigma);
     //Gaussian.y = exp(-0.5 / (sigma * sigma));
     //Gaussian.z = Gaussian.y * Gaussian.y;

     // recomment：
     //   1/4 framebuffer, size 7,strength 2.75,1 pass shape light，4 pass smooth light
     //   it's hard to special light spark  
     // use color * 1.0/(1.0 + lum + 0.5);
     //   will avoid light spark effect. 

     // widthOverHeight = (1.0f * source.width) / (1.0f * source.height)
     // one pass 
     // blurStrength = 0.75; 2.75;
     // blurSize = 5; 7;
     // sigma = 5; 7;

     // framesize = 256 or framebuffersize/4
     // classic render mode:
     // blurSize = 5,strength = 2.75,iters = 1,ctb = 1
     // pbr mode: performance and good looking 
     // blur_iters = 2,1
	// blur_size = 5
	// blur_strength = 3.75
	// spread = 1,1.5
     // 
     float  woh = u_params.z/u_params.w;
     float  direction   = u_params.x;
     vec2   pixelSize   = u_params.zw; 
     int    blurSize = u_blur.x;
     float  sigma = u_blur.x;
     float  blurStrength = u_blur.y; 
     float  iters = u_blur.z;

     vec2  dir = vec2(direction,!direction);
     vec2  uv  = v_texcoord0.xy;
     int   KSIZE = blurSize; 
     vec2  ss = u_params.y*dir;
     vec2  d  = dir;
     //float weights = GaussianD1(d.x,d.y, sigma);
     float weights = GaussianD2(0.0, sigma);
     vec3  color   = texture2D( _MainTex, uv).rgb * weights;
     for( int px = 1; px < KSIZE; px ++ ) {
          //d = dir *px;
          //float w = GaussianD1(d.x,d.y,sigma);
          //float w = Gaussian(px*px, sigma);          
          float w = GaussianD2(px*px, sigma);          
          vec2  ofs = dir * pixelSize * px *ss;
          float ctb = 1.0f;  //1/(px*px);
          vec3  sample1 = texture2D( _MainTex, uv + ofs).rgb*ctb*blurStrength;
          vec3  sample2 = texture2D( _MainTex, uv - ofs).rgb*ctb*blurStrength;
          color += (sample1 + sample2) * w;
          weights += 2.0 * w;
     }
     // gl_FragData[0] = vec4(color/weights, 1.0);
     // if(gl_FragCoord.x>textureSize(_MainTex,0).x*3/4 && gl_FragCoord.y<textureSize(_MainTex,0).y/4)
     //   color = vec3(1,0,0);
     gl_FragData[0] = vec4(color,1.0);   


#endif 
}



 