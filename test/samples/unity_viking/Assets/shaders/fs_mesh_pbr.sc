// for metalness flow 
// use albedo,metallic,roughness
// compatible with specular params when special specular mode and specular map 
//    specular no-recommendation, but for scene viking test 
$input v_texcoord0, v_normal, v_posWS

#define FRAGMENT_SHADER

#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"
#include "common/shadow.sh"
 
// fence does not provide specular,can not process it like specular texture,notice
// need special process 
// uniform.x = 0 must set to 0

#define _DETAIL 1
#define _ALPHATEST_ON 1
#define _BLOOM_EFFECT 1

 
// brief solution for mobile 
// above 4 - 6 texture units
//  it support detail texture, too expensive 
// step optimize: remove or combine texture 
// pbr could only have 3-4 textures
// usage: basemap,normalmap
//        metal map or metal params,roughness ,or combine map
//        cubemap
// future: metallic,roughness,ao could combine into one texture by artist       
SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal,     1); 
SAMPLER2D(s_metallic,   2);
SAMPLERCUBE(s_texCube,  3);

SAMPLER2D(s_detailcolor,    4);
SAMPLER2D(s_detailnormal,   5);
//SAMPLER2D(s_brdfMap,6);

uniform vec4 u_params;              
uniform vec4 u_diffuseColor;
uniform vec4 u_specularColor;
uniform vec4 u_misc;                // .x = Cutoff, .y = DetailNormalMapScale
uniform vec4 u_tiling;	            // .xy = base tiling, .wz = detail tiling if exist  
uniform vec4 u_emissionColor;      

uniform vec4 u_FogColor;
uniform vec4 u_FogParams;

static vec4  _Color                = u_diffuseColor;                       // u_diffuseColor;
static vec4  _SpecColor            = u_specularColor;                      // u_specularColor;
static vec4  _EmissionColor        = vec4(0, 0, 0, 0);

static float _Cutoff               = u_misc.x;
static float _DetailNormalMapScale = u_misc.y;
static vec2  _DetailTiling         = u_tiling.wz;

static float _Metallic             = u_params.z;
static float _Roughness            = u_params.w;
 
static vec4 _FogColor              = vec4(0.5,0.5,0.5,0);
static vec4 _FogParams             = vec4(1,1,20,1000);                    // .xy reserve, .z = start, .w = end, for Linear mode

static float _BrightThresohd       = 0.9f;
static float _GlowExpouse         = 2.0f;

#define _MainTex            s_basecolor 
#define _NormalMap          s_normal 
#define _MetallicGlossMap   s_metallic 
#define _CubeMap            s_texCube 

#define _BrdfMap            s_brdfMap 
#define _SpecGlossMap       s_metallic 

#define _DetailAlbedoMap    s_detailcolor
#define _DetailNormalMap    s_detailnormal
//#define _EmissionMap        

#define _METALLICGLOSSMAP 1     // use metalness map 
#define _SPECGLOSSMAP 1         // use specular map 
#define _SPECULAR_COMPATIBLE 1
#define _DETAIL_MULX2 1
//#define _BRDFMAP 1
#include "common/pbr_protocol.sh"


#define COLOR_SPACE_TRANS 1
#define GAMMA_TO_LINEAR_EXACT 1

#define PerPixelWorldNormal      getPixelNormalFromMap
#define NormalizePerPixelNormal  normalize

#define LinearColorSpace_DielectricSpec vec4(0.04, 0.04, 0.04, 1.0 - 0.04) 
#define LinearColorSpace_Double vec4(2.0, 2.0, 2.0, 2.0)
#define SPECULAR_SCALE 1.58 
#define ALBEDO_SCALE 1
#define ADAPT_BRIGHTMAX 1.0
//utils
inline float GammaToLinearSpaceExact (float value)
{
    if (value <= 0.04045F)
        return value / 12.92F;
    else if (value < 1.0F)
        return pow((value + 0.055F)/1.055F, 2.4F);
    else
        return pow(value, 2.2F);
}

inline vec3 GammaToLinearSpace (vec3 sRGB)
{
#ifndef GAMMA_TO_LINEAR_EXACT
    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);
#else     
    // Precise version, useful for debugging.
    return vec3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
#endif 
}

inline float LinearToGammaSpaceExact (float value)
{
    if (value <= 0.0F)
        return 0.0F;
    else if (value <= 0.0031308F)
        return 12.92F * value;
    else if (value < 1.0F)
        return 1.055F * pow(value, 0.4166667F) - 0.055F;
    else
        return pow(value, 0.45454545F);
}

inline vec3 LinearToGammaSpace (vec3 linRGB)
{
    linRGB = max(linRGB, vec3(0.h, 0.h, 0.h));
#ifndef GAMMA_TO_LINEAR_EXACT    
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
#else     
    // Exact version, more expensive
    return vec3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
#endif     
}

vec3 toLinearAcc(vec3 _rgb)
{   //  if we need
#ifdef COLOR_SPACE_TRANS
    return GammaToLinearSpace(_rgb);
#else 
    return _rgb;
#endif 
}

vec3 toGammaAcc(vec3 _rgb) 
{   // todo 
#ifdef COLOR_SPACE_TRANS
    return LinearToGammaSpace(_rgb);
#else     
    return _rgb;
#endif 
}
  
inline vec3 SafeNormalize(vec3 inVec)
{
    float dp3 = max(0.001f, dot(inVec, inVec));
    return inVec * rsqrt(dp3);  // be careful
}


//--------------------------------------------------------------------
// app
// ENV, FragmentData,Light    
// range of semiconductors [0.2, 0.45] 
vec3 blend_term(vec3 kD, vec3 kS, vec3 kBase,float metallic)
{
  float sr = smoothstep(0.2, 0.45, metallic);
  vec3  dielectric = kD + kS;
  vec3  metal = kS * kBase;
  return mix(dielectric, metal, sr);
}  

//----------------------------------------
// unity protocol get from unity standard 
vec3 LerpWhite2(vec3 b, float t)
{
    float oneMinusT = 1 - t;
    return vec3(oneMinusT, oneMinusT, oneMinusT) + b * t;
}

//-------------------------------------
struct AntEnv
{
    vec3    normal;
    vec3    refvm;
    vec3    viewdir;
};

struct AntLight
{
    vec3   color;
    vec3   dir;
    float  type;
    float  att;
};

struct SurfaceMetalStandard {
    vec3  Albedo;
    vec3  Normal;
    vec3  Emission;
    float Metallic;
    float Roughness;
    float Occlusion;
    float Alpha;
};

struct FragmentCommonData
{
    vec3  diffColor, specColor;
    float oneMinusReflectivity, roughness;
    vec3  normalWorld;
    vec3  eyeVec;
    float alpha;
    vec3  posWorld;

    float metallic;

    vec3  reflUVW;
    vec3  tangentSpaceNormal;
};


inline AntEnv MainEnv( vec2 st,vec3 camPos, vec3 worldPos,vec3 normal)
{
    AntEnv env;
    vec3 N = PerPixelWorldNormal(_NormalMap, st, worldPos, normal);
    vec3 V = normalize( camPos - worldPos ).xyz;
    vec3 R = reflect(-V, N); 
    env.normal  = N;
    env.refvm   = R;
    env.viewdir = V;
    return env;
}

// main light is directional 
inline AntLight MainLight()
{
    AntLight l;
    l.color = toLinearAcc(directional_color[0].rgb* directional_intensity[0].x*1.5) ;
    l.type  = directional_color[0].w;
    l.dir   = SafeNormalize( directional_lightdir[0].xyz);   
    l.att   = 1;
   
    return l;
}
// for any light type 
inline AntLight AddtiveLight(vec3 worldPos)
{
    AntLight l;
    l.color = toLinearAcc(directional_color[0].rgb* directional_intensity[0].x) ;
    l.type  = directional_color[0].w;
    vec3  dir = (directional_lightdir[0].xyz- l.type* worldPos);
    float distance = max(0.001,dot(dir,dir));
    float attenuation = 1.0 / distance ;
    l.dir   = dir*rsqrt(distance); 
    l.att   = attenuation;
    return l;
}

void ParamsSetup()
{
     _Cutoff                 = u_misc.x;
     _DetailNormalMapScale   = u_misc.y;
     _DetailTiling           = u_tiling.wz;
     _Color                  = u_diffuseColor;
     _SpecColor              = u_specularColor;
     _EmissionColor          = vec4(0,0,0,0);

     _Metallic               = u_params.z;
     _Roughness              = u_params.w;

     //_Glossiness           = 1- u_params.w;  
     //_GlossMapScale        = 1.0f;

     // get from application later 
     //_FogColor  = u_FogColor;
     //_FogParams = u_FogParams;
     _FogColor = vec4(0.5,0.5,0.5,0);
     _FogParams = vec4(1,1,20,1000);
}  

vec3 Albedo(vec2 i_tex)
{
    vec4  texcoords = vec4(i_tex.x, i_tex.y, i_tex.x*_DetailTiling.x, i_tex.y*_DetailTiling.y);
    vec3  albedo = _Color.rgb * texture2D (_MainTex, texcoords.xy).rgb;
#if _DETAIL
    #if (SHADER_TARGET < 30)
        float mask = 1;
    #else
        //float mask = DetailMask(texcoords.xy);
        float mask = 1;
    #endif
    
    if( textureSize(_DetailAlbedoMap,0).x > 1 ) {
        vec3 detailAlbedo = texture2D (_DetailAlbedoMap, texcoords.zw).rgb;
        #if _DETAIL_MULX2
            albedo *= LerpWhite2 (detailAlbedo* LinearColorSpace_Double.rgb , mask);
        #elif _DETAIL_MUL
            albedo *= LerpWhite2 (detailAlbedo, mask);
        #elif _DETAIL_ADD
            albedo += detailAlbedo * mask;
        #elif _DETAIL_LERP
            albedo = lerp (albedo, detailAlbedo, mask);
        #endif
    }
#endif
    return albedo;
}

// need optimize read,cache it 
float Alpha(vec2 uv)
{
    return texture2D(_MainTex, uv).a * _Color.a;
}

inline vec3 PreMultiplyAlpha (vec3 diffColor, float alpha, float oneMinusReflectivity, out float outModifiedAlpha)
{
    #if defined(_ALPHAPREMULTIPLY_ON)
        // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
        // Transparency 'removes' from Diffuse component
        diffColor *= alpha;

        #if (SHADER_TARGET < 30)
            // SM2.0: instruction count limitation
            // Instead will sacrifice part of physically based transparency where amount Reflectivity is affecting Transparency
            // SM2.0: uses unmodified alpha
            outModifiedAlpha = alpha;
        #else
            // Reflectivity 'removes' from the rest of components, including Transparency
            // outAlpha = 1-(1-alpha)*(1-reflectivity) = 1-(oneMinusReflectivity - alpha*oneMinusReflectivity) =
            //          = 1-oneMinusReflectivity + alpha*oneMinusReflectivity
            outModifiedAlpha = 1-oneMinusReflectivity + alpha*oneMinusReflectivity;
        #endif
    #else
        outModifiedAlpha =   alpha;
    #endif
    return diffColor;
}


vec2 MetallicRough(vec2 uv)
{
    vec2 mg;
#ifdef _METALLICGLOSSMAP
    mg.r = texture2D(_MetallicGlossMap, uv).r;
#else
    mg.r = _Metallic;
#endif

#ifdef _SPECGLOSSMAP
    mg.g = 1.0f - texture2D(_SpecGlossMap, uv).r;
#else
    mg.g = 1.0f - _Glossiness;
#endif
    return mg;
}


vec4 SpecularGloss(vec2 uv,float gloss)
{
    vec4 sg;
#ifdef _SPECGLOSSMAP
    #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
        sg.rgb = texture2D(_MetallicGlossMap, uv).rgb;
        sg.a = texture2D(_MainTex, uv).a;
    #else
        sg = texture2D(_MainTex, uv);
    #endif
    sg.a *= gloss;
#else
    sg.rgb = _MetallicGlossMap.rgb;
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        sg.a = texture2D(_MainTex, uv).a * gloss;
    #else
        sg.a = gloss;
    #endif
#endif
    return sg;
}

vec3 Emission(vec2 uv)
{
#ifndef _EMISSION
    return 0;
#else
    return texture2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
#endif
}


inline float OneMinusReflectivityFromMetallic(float metallic)
{
    float  oneMinusDielectricSpec = LinearColorSpace_DielectricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

inline vec3 DiffuseAndSpecularFromMetallic (vec2 uv,vec3 albedo, out float metallic, out vec3 specColor, out float oneMinusReflectivity)
{
    float _USE_METALGLOSSMAP = u_params.y;    
    if( _USE_METALGLOSSMAP < 1 ) {
        metallic  = texture2D(_MetallicGlossMap, uv).r;
    } else {
        metallic = _Metallic;
    }

    specColor = lerp (LinearColorSpace_DielectricSpec.rgb, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
}

inline vec3 DiffuseAndSpecularFramSpecular(vec2 uv,vec3 albedo,out float metallic,out vec3 specColor, out float oneMinusReflectivity)
{
    vec3  specGloss = _SpecColor.rgb;    
    float _USE_SPECGLOSSMAP = u_params.y;
    if( _USE_SPECGLOSSMAP < 1 ) {
        specGloss = texture2D(_SpecGlossMap, uv).rgb;
    } 

    specColor = specGloss.xyz*SPECULAR_SCALE;
    specColor = mix(specColor, albedo,1-specColor);
    metallic = max(specColor.x,max(specColor.y,specColor.z));
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo*ALBEDO_SCALE;
}

vec4 FogLinear(vec4 color,vec3 camPos,vec3 worldPos,vec4 fogColor,vec4 fogParams)
{
    float fog_coord =  length(camPos-worldPos); 
   float fogFactor = (fogParams.w - fog_coord)/(fogParams.w - fogParams.z);
   fogFactor = clamp( fogFactor, 0.0, 1.0 );
   color = mix(fogColor, color, fogFactor);
   return color;
}


vec3 EnvBRDF( vec3 specColor, float g, float ndotv  )
{
    vec4 t = vec4( 1/0.96, 0.475, (0.0275 - 0.25 * 0.04)/0.96, 0.25 );
    t *= vec4( g, g, g, g );
    t += vec4( 0, 0, (0.015 - 0.75 * 0.04)/0.96, 0.75 );
    float a0 = t.x * min( t.y, exp2( -9.28 * ndotv ) ) + t.z; 
    float a1 = t.w;
    return saturate( a0 + specColor * ( a1 - a0 ) );
}



vec3 FragmentAmbient(AntEnv env, vec3 F0,float metallic,float roughness,vec3 albedo)
{
    vec3 N = env.normal;
    vec3 R = env.refvm;
    vec3 V = env.viewdir;

    // F0 must keep source state
    float ndotv = max(dot(N,V),0.0);  
    //vec3 eF = fresnelSchlick( ndotv, F0);        
    //vec3 eF = fresnelSchlickRoughness2( ndotv, F0, roughness);     // hight section is suitable, avoid f0 too exposure    
    vec3  eF = fresnelSchlickRoughness( ndotv, F0, roughness);       // low section is suitable
    
    vec3 ekS = eF;
    vec3 ekD = 1.0 - ekS;
    ekD *= 1.0 - metallic;	  // no accurate,if not provide pixel control from map                                 
    
    // #1. 
    // trick, approximate effect,not correct but enough good on mobile
    // optimize avoid an TM, instead of irr, use envcube low leve simulate 
    // in the future 
    //  or optimize by SH, decrase consumption on mobile
    //  or use lightmap
    vec3 irradiance  = toLinearAcc(textureCubeLod(_CubeMap,N, 12).xyz);
    vec3 diffuse     = ekD*irradiance*albedo; 

    // #2.
    // prefilter map ,low cost lod calculate 
    // float lod       = 0.1 + 5.0*(roughness);
    // vec3  radiance  = toLinearAcc(textureCubeLod(s_texCube, R, lod).xyz);
    float rough     = roughness; rough *= 1.7 - 0.7 * rough;
    float lod       = 0.1 + 6.0*(rough);        // this formula close to unity effect 
    vec3  radiance  = toLinearAcc(textureCubeLod(_CubeMap, R, lod).xyz);

    // more accurate, 
    // use lut map, experimal tested 
#ifdef _BRDFMAP     
    // accurate 
    vec2   envBRDF = texture2D( _BrdfMap,vec2(roughness,ndotv)).xy;
    vec3   specular = radiance * (eF * envBRDF.x + envBRDF.y);  
#else     
    // use analytical function resolve 
     vec3  specular = radiance * EnvBRDF(eF,1-roughness,ndotv);
     float surfaceReduction = 1.0 / (roughness*roughness + 1.0);
     specular = surfaceReduction *specular/PI;
#endif 
    vec3 color = (diffuse + specular);
    return color;
} 

// ENV, FragmentData,Light 
vec3 FragmentPBR( AntEnv env, AntLight light, vec3 albedo, vec3 specColor, float metallic, float roughness ) 
{  
    vec3 N = env.normal;
    vec3 V = env.viewdir;
    vec3 L = light.dir;
    vec3 H = normalize( V+L);
    vec3 radiance = light.att * light.color;

    float D  = DistributionGGX(N, H, roughness);
    float G  = GeometrySmith(N, V, L, roughness);      
    vec3  F  = fresnelSchlick(max(dot(H, V), 0.0), specColor );
    //vec3  F  = fresnelSchlickRoughness(max(dot(H, V), 0.0), F0,roughness);

    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.0);
    vec3  nominator = D*G*F;

    float denominator = BrdfDenominatorStd(NdotV,NdotL);
    //float denominator = BrdfDenominatorOpt(NdotV,NdotL,roughness);
    //float denominator = 1/(PI/4);
    vec3  specular = nominator / denominator;     

    vec3 kS = F;
    vec3 kD = vec3_splat(1.0)- kS;
    kD *= 1.0 - metallic;

    vec3 color = kD*albedo/PI;     //unity does not div PI, unity is no accurate but seems ok 

    color  = (color + specular)*radiance*NdotL;
    return color;        
} 


inline FragmentCommonData MetalSetup (vec2 i_tex)
{
    float oneMinusReflectivity = 0;    
    float roughness  = _Roughness; 
    float metallic   = 0;
    vec3  albedo     = Albedo(i_tex);
    albedo = toLinearAcc( albedo ); 

    vec3  F0 = LinearColorSpace_DielectricSpec.rgb; 

#ifdef _SPECULAR_COMPATIBLE        
    float _METALNESS_FLOW = u_params.x;
    if (_METALNESS_FLOW < 1.0) { 
        albedo = DiffuseAndSpecularFromMetallic( i_tex, albedo,metallic,F0,oneMinusReflectivity);
    }else{ 
        albedo = DiffuseAndSpecularFramSpecular( i_tex, albedo,metallic,F0,oneMinusReflectivity);
    }
#else
    albedo = DiffuseAndSpecularFromMetallic( i_tex, albedo,metallic,F0,oneMinusReflectivity);
#endif     

    FragmentCommonData o = (FragmentCommonData)0;
    o.diffColor = (albedo);     
    o.specColor = (F0);     
    o.metallic  = metallic;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.roughness = roughness;
    return o;
}

inline FragmentCommonData FragmentSetup (vec2 i_tex, vec3 i_eyeVec,  vec3 i_normal, vec3 i_posWorld)
{
    float alpha = Alpha(i_tex);
    #if defined(_ALPHATEST_ON)
        if (alpha - _Cutoff <0  )  {
           discard;
        }      
    #endif

    FragmentCommonData o = MetalSetup(i_tex);
    o.normalWorld =  i_normal; 
    o.eyeVec = (i_eyeVec);
    o.posWorld = i_posWorld;

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);

    return o;
}
// Tone brightness 
vec3 GlowToneMark(vec3 color,float exposure) 
{
   return vec3(1.0,1.0,1.0) - exp(-color * exposure);
}

//main quality
// newLum=lastLum+(currentLum–lastLum)∗(1.0–0.9830∗frameTime )
// brightMax empirical value =1.0
//           exposuse 1.6
// or calculate fullscreen brightMax (need more pass)
vec3 ToneMapping(vec3 color,float exposure,float brightMax)
{
    float Yd = exposure * (exposure/brightMax + 1.0) / (exposure + 1.0);
    color *= Yd;
    return color;
}

//single pass simulate
vec3 ToneMappingSimulateHdr(vec3 color,float exposure)
{
    float exposure2 = exposure; 
    float lum = dot(color,vec3(0.2126,0.7152,0.0722));
    float mapLum = (lum*(1+lum/(exposure2*exposure2)))/(1.0+lum);
    return (mapLum/lum)*color;
}


float GrayLumiance(vec3 color)
{
    return max(color.x,max(color.y,color.z));
    //return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

//color = color*Vignette(v_texcoord0.xy*2.0-1.0,0.55,1.5);
//screen vignette 
float Vignette(vec2 pos, float inner, float outer)
{
  float r = length(pos);
  r = 1.0 - smoothstep(inner, outer, r);
  return r;
}

vec3 LightGlow(vec3 color,AntEnv env,float brightness,float strength)
{
    float lightAliggnment = dot(-env.viewdir,  env.refvm);
    float alignmentFactor = clamp(lightAliggnment, 0.0, 1.0);
    color += color * brightness * alignmentFactor * strength;
    return color;
}


//-------------------------------------   
void main() 
{   
    ParamsSetup(); 

    float distanceVS = v_posWS.w;
    vec4 posWS = vec4(v_posWS.xyz, 1.0);

    AntEnv env = MainEnv(v_texcoord0.xy, u_eyepos.xyz, posWS.xyz, v_normal);

    AntLight light = MainLight();

    FragmentCommonData s = FragmentSetup(v_texcoord0, env.viewdir, env.normal, posWS.xyz);

    vec3 color = FragmentPBR( env, light, s.diffColor,s.specColor,s.metallic, s.roughness);
    color += FragmentAmbient(env,s.specColor,s.metallic,s.roughness,s.diffColor);
    color += Emission(v_texcoord0.xy);
  
	//#include "mesh_shadow/fs_ext_shadowmaps_color_lighting_main.sh" 
	//visibility -= 0.25f;	
    //color = vec4(color*visibility ,1.0); 

#ifdef _BLOOM_EFFECT
    vec3  glow = GlowToneMark(color,_GlowExpouse);
    float lum  = GrayLumiance(color);    
    if( lum>_BrightThresohd ) {
        gl_FragData[1] = vec4(glow,1);
    }else {
        //gl_FragData[1] = vec4(0,0,0,1);  
        gl_FragData[1] = vec4(color,1);
    }
#endif
    float visibility = shadow_visibility(distanceVS, posWS);
    color = mix(u_shadow_color.rgb, color.rgb, visibility);

    color = FogLinear(vec4(color,1), u_eyepos, posWS, _FogColor, _FogParams);
    color = ToneMapping(color,0.90,1);
    //color = ToneMappingSimulateHdr(color,1);
    //color += LightGlow(color,env,lum,2.8);            
    // bgfx impl Rheinhardt space, too cheap,too simple 
    // color = toneMapping(color,1.0f);

    color = toGammaAcc(color);
    
    gl_FragData[0] = vec4(color,s.alpha); 
} 

 

 