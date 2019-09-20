// specular flow
// clone from unity directly
// simplify some features
// use albedo,specular,normal map
$input v_texcoord0, v_lightdir, v_viewdir,v_normal,v_tangent,v_bitangent, v_texcoord4,v_texcoord5,v_texcoord6,v_texcoord7,v_worldPos,v_camPos
 
#include <common.sh>
#include "common/uniforms.sh"
#include "common/lighting.sh"

                
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
SAMPLERCUBE(s_texCube,3);

SAMPLER2D(s_detailcolor,4);
SAMPLER2D(s_detailnormal,5);

// irr could be removed to improve performance  
//SAMPLER2D(s_emission,6);

uniform vec4 u_params;
uniform vec4 u_diffuseColor;
uniform vec4 u_specularColor;
uniform vec4 u_misc;
uniform vec4 u_tiling;	

uniform vec4 u_FogColor;
uniform vec4 u_FogParams;
uniform vec4 u_Emission;

vec4  _Color;               // u_diffuseColor;
vec4  _SpecColor;           // u_specularColor;
float _Glossiness;
float _Smoothness;
float _Cutoff;
float _GlossMapScale;
float _DetailNormalMapScale;
vec4  _EmissionColor;
vec2  _DetailTiling;
 
vec4 _FogColor;
// z = start , useful for Linear mode
// w = end , useful for Linear mode
vec4 _FogParams;


  
#define _MainTex            s_basecolor 
#define _NormalMap          s_normal 
#define _SpecGlossMap       s_metallic 
#define _MetallicGlossMap   s_metallic 
#define _CubeMap            s_texCube 
#define _BrdfMap            s_brdfMap 

#define _DetailAlbedoMap    s_detailcolor
#define _DetailNormalMap    s_detailnormal
#define _DetailMask         s_metallic
//#define _EmissionMap        


// Unity 
#ifdef UNITY_COLORSPACE_GAMMA
#define unity_ColorSpaceGrey vec4(0.5, 0.5, 0.5, 0.5)
#define unity_ColorSpaceDouble vec4(2.0, 2.0, 2.0, 2.0)
#define unity_ColorSpaceDielectricSpec vec4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)
#define unity_ColorSpaceLuminance vec4(0.22, 0.707, 0.071, 0.0) 
#else 
#define unity_ColorSpaceGrey vec4(0.214041144, 0.214041144, 0.214041144, 0.5)
//#define unity_ColorSpaceDouble vec4(4.59479380, 4.59479380, 4.59479380, 2.0)
#define unity_ColorSpaceDouble vec4(2.0, 2.0, 2.0, 2.0)
#define unity_ColorSpaceDielectricSpec vec4(0.04, 0.04, 0.04, 1.0 - 0.04) 
#define unity_ColorSpaceLuminance vec4(0.0396819152, 0.458021790, 0.00609653955, 1.0) // Legacy: alpha is set to 1.0 
#endif
#define UNITY_CONSERVE_ENERGY  1
#define _SPECGLOSSMAP 1 
#define BRDF_PBS BRDFSM_Unity_PBS    // could custom for any sm 

#define UNITY_SETUP_BRDF_INPUT SpecularSetup
#define PerPixelWorldNormal getPixelNormalFromMap
#define NormalizePerPixelNormal  normalize
#define _ALPHATEST_ON 1
//#define _ALPHAPREMULTIPLY_ON 1
#define UNITY_BRDF_GGX 1
#define UNITY_INV_PI 1/PI

#define _DETAIL_MULX2  1
#define _DETAIL 1
//#define _DETAIL_LERP 1  
     
#define SPECULAR_SCALE 1.58 
#define ALBEDO_SCALE 1.0

#include "pbr_protocol.sh"   

//utils

#define FOG_LINEAR 1

#define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(-(coord), 0)
#if defined(FOG_LINEAR)
    // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float _FogFactor = (coord) * _FogParams.z + _FogParams.w
#elif defined(FOG_EXP)
    // factor = exp(-density*z)
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float _FogFactor = _FogParams.y * (coord); _FogFactor = exp2(-_FogFactor)
#elif defined(FOG_EXP2)
    // factor = exp(-(density*z)^2)
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float _FogFactor = unity_FogParams.x * (coord); _FogFactor = exp2(-_FogFactor*_FogFactor)
#else
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float _FogFactor = 0.0
#endif
#define UNITY_FOG_LERP_COLOR(col,fogCol,fogFac) col.rgb = lerp((fogCol).rgb, (col).rgb, saturate(fogFac))
#define UNITY_CALC_FOG_FACTOR(coord) UNITY_CALC_FOG_FACTOR_RAW(UNITY_Z_0_FAR_FROM_CLIPSPACE(coord))
#define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_CALC_FOG_FACTOR((coord).x); UNITY_FOG_LERP_COLOR(col,fogCol,unityFogFactor)
#define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,fixed4(0,0,0,0))

void ParamsSetup()
{
    _Cutoff     = u_misc.x;
    _DetailTiling = u_tiling.wz;
    _DetailNormalMapScale = u_misc.y;
    _Color      = u_diffuseColor;
    _SpecColor  = u_specularColor;
    _Glossiness = 1- u_params.w;  
    _GlossMapScale = 1.0f;
    _EmissionColor = vec4(0,0,0,0);
    //_EmissionColor = u_Emission;


    // get from application later 
    // u_FogColor = vec4(0.5,0.5,0.5,0);
    // u_FogParams = vec4(1,1,20,1000);
    _FogColor = vec4(0.5,0.5,0.5,0);
    _FogParams = vec4(1,1,20,1000);
}  

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
    //return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);
    // Precise version, useful for debugging.
    return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
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

inline half3 LinearToGammaSpace (vec3 linRGB)
{
    linRGB = max(linRGB, vec3(0.h, 0.h, 0.h));
    //return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);
    // Exact version, more expensive
    return vec3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
}

#define COLOR_SPACE_TRANS 1

vec3 toLinearAcc(vec3 _rgb)
{   // todo if we need
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

  
//app
vec3 directlight_radiance(vec3 lightColor) 
{
    return lightColor;
}

vec3 pointlight_radiance(vec3 lightPos,vec3 lightColor,vec3 worldPos) 
{
    vec3  lightDir = lightPos - worldPos;
    float distance = max(0.0001,dot(lightDir,lightDir)); 
    float attenuation = 1.0 / distance;    // quadric attenuation 
    vec3  radiance = lightColor * attenuation;
    return radiance;
}



inline float Pow5 (float x)
{
    return x*x * x*x * x;
}

inline vec3 Pow5 (vec3 x)
{
    return x*x * x*x * x;
}


float SmoothnessToPerceptualRoughness(float smoothness)
{
    return (1 - smoothness);
}

float PerceptualRoughnessToRoughness(float perceptualRoughness)
{
    return perceptualRoughness * perceptualRoughness;
}

float RoughnessToPerceptualRoughness(float roughness)
{
    return sqrt(roughness);
}

float DisneyDiffuse(float NdotV, float NdotL, float LdotH, float perceptualRoughness)
{
    float  fd90 = 0.5 + 2 * LdotH * LdotH * perceptualRoughness;
    // Two schlick fresnel term
    float lightScatter   = (1 + (fd90 - 1) * Pow5(1 - NdotL));
    float viewScatter    = (1 + (fd90 - 1) * Pow5(1 - NdotV));
    return lightScatter * viewScatter;
}
// Smith-Schlick derived for Beckmann
inline float SmithBeckmannVisibilityTerm (float NdotL, float NdotV, float roughness)
{
    return 0;
    // float c = 0.797884560802865h; // c = sqrt(2 / Pi)
    // float k = roughness * c;
    // return SmithVisibilityTerm (NdotL, NdotV, k) * 0.25f; // * 0.25 is the 1/4 of the visibility term
}
inline float NDFBlinnPhongNormalizedTerm (float NdotH, float n)
{
    return 0;
    // float normTerm = (n + 2.0) * (0.5/PI);
    // float specTerm = pow (NdotH, n);
    // return specTerm * normTerm;
}


inline float SmithJointGGXVisibilityTerm (float NdotL, float NdotV, float roughness)
{
#if 0
    // Original formulation:
    //  lambda_v    = (-1 + sqrt(a2 * (1 - NdotL2) / NdotL2 + 1)) * 0.5f;
    //  lambda_l    = (-1 + sqrt(a2 * (1 - NdotV2) / NdotV2 + 1)) * 0.5f;
    //  G           = 1 / (1 + lambda_v + lambda_l);

    // Reorder code to be more optimal
    half a          = roughness;
    half a2         = a * a;

    half lambdaV    = NdotL * sqrt((-NdotV * a2 + NdotV) * NdotV + a2);
    half lambdaL    = NdotV * sqrt((-NdotL * a2 + NdotL) * NdotL + a2);

    // Simplify visibility term: (2.0f * NdotL * NdotV) /  ((4.0f * NdotL * NdotV) * (lambda_v + lambda_l + 1e-5f));
    return 0.5f / (lambdaV + lambdaL + 1e-5f);  // This function is not intended to be running on Mobile,
                                                // therefore epsilon is smaller than can be represented by half
#else
    // Approximation of the above formulation (simplify the sqrt, not mathematically correct but close enough)
    float a = roughness;
    float lambdaV = NdotL * (NdotV * (1 - a) + a);
    float lambdaL = NdotV * (NdotL * (1 - a) + a);

#if defined(SHADER_API_HLSL)
    return 0.5f / (lambdaV + lambdaL + 1e-4f); // work-around against hlslcc rounding error
#else
    return 0.5f / (lambdaV + lambdaL + 1e-5f);
#endif

#endif
}

inline float GGXTerm (float NdotH, float roughness)
{
    float a2 = roughness * roughness;
    float d = (NdotH * a2 - NdotH) * NdotH + 1.0f;      // 2 mad
    return UNITY_INV_PI * a2 / (d * d + 1e-7f);         // This function is not intended to be running on Mobile,
                                                        // therefore epsilon is smaller than what can be represented by half
}

inline vec3 FresnelTerm (vec3 F0, float cosA)
{
    float t = Pow5 (1 - cosA);   // ala Schlick interpoliation
    return F0 + (1-F0) * t;
}

vec3 mylerp(vec3 a, vec3 b, float s)
{
    return vec3(a + (b - a) * s);       
}

inline vec3 FresnelLerp (vec3 F0, vec3 F90, float cosA)
{
    float t = Pow5 ( (1 - cosA) );   // ala Schlick interpoliation
    //return lerp (F0, F90, t);
    return mix (F0, F90, t);
}

float SpecularStrength(vec3 specular)
{
    #if (SHADER_TARGET < 30)
        // SM2.0: instruction count limitation
        // SM2.0: simplified SpecularStrength
        return specular.r; 
    #else
        return max (max (specular.r, specular.g), specular.b);
    #endif
}
#define UNITY_CONSERVE_ENERGY_MONOCHROME 1
// Diffuse/Spec Energy conservation
inline vec3 EnergyConservationBetweenDiffuseAndSpecular (vec3 albedo, vec3 specColor, out float oneMinusReflectivity)
{
    oneMinusReflectivity = 1 - SpecularStrength(specColor);
    #if !UNITY_CONSERVE_ENERGY
        return albedo;
    #elif UNITY_CONSERVE_ENERGY_MONOCHROME
        return albedo * oneMinusReflectivity;    // use this before 
    #else
        return albedo * (vec3(1,1,1) - specColor);
    #endif
}

inline float OneMinusReflectivityFromMetallic(float metallic)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    float oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}

inline vec3 DiffuseAndSpecularFromMetallic (vec3 albedo, float metallic, out vec3 specColor, out float oneMinusReflectivity)
{
    specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, albedo, metallic);
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);
    return albedo * oneMinusReflectivity;
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

//----------------------------------------
// unity protocol from unity standard 
vec4 SpecularGloss(vec2 uv,float gloss)
{
    vec4 sg;
#ifdef _SPECGLOSSMAP
    #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
        sg.rgb = texture2D(_SpecGlossMap, uv).rgb;
        sg.a = texture2D(_MainTex, uv).a;
    #else
        // if( float(textureSize(_SpecGlossMap,0).x) > 1.0 )
        //     sg = texture2D(_SpecGlossMap, uv);
        // else 
        //     sg.rgb = _SpecColor.rgb;
        sg = texture2D(_SpecGlossMap, uv);
        if(sg.r == 1.0 && sg.g == 0 && sg.b == 0 ) //default spacular 
        {
           sg.rgb = _SpecColor.rgb;
           sg.a = _SpecColor.a;
        }
    #endif
    sg.a *= gloss;
#else
    sg.rgb = _SpecColor.rgb;
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
        sg.a = texture2D(_MainTex, uv).a * gloss;
    #else
        sg.a = gloss;
    #endif
#endif

    return sg;
}


struct UnityLight
{
    vec3   color;
    vec3   dir;
    float  type;
};

struct UnityIndirect
{
    vec3 diffuse;
    vec3 specular;
};

struct UnityGI
{
    UnityLight light;
    UnityIndirect indirect;
};

struct UnityEnv
{
    vec3 normal;
    vec3 refvm;
    vec3 viewdir;
};



struct FragmentCommonData
{
    vec3  diffColor, specColor;
    float oneMinusReflectivity, smoothness;
    vec3  normalWorld;
    vec3  eyeVec;
    float alpha;
    vec3  posWorld;

#if UNITY_STANDARD_SIMPLE
    vec3  reflUVW;
#endif

#if UNITY_STANDARD_SIMPLE
    vec3 tangentSpaceNormal;
#endif
};

inline vec3 Unity_SafeNormalize(vec3 inVec)
{
    float dp3 = max(0.001f, dot(inVec, inVec));
    return inVec * rsqrt(dp3);  // be careful
}

UnityLight MainLight()
{
    UnityLight l;
    l.color = toLinearAcc(directional_color[0].rgb* directional_intensity[0].x) ;
    l.dir   = Unity_SafeNormalize(directional_lightdir[0].xyz);   //need normalized 
    l.type  = 0;  //directional_color[0].w 
    return l;
}

float Alpha(vec2 uv)
{
    return (texture2D(_MainTex, uv).a); // * _Color.a;
}

float DetailMask(vec2 uv)
{
    return texture2D (_DetailMask, uv).a;
}

vec3 LerpWhite2(vec3 b, float t)
{
    float oneMinusT = 1 - t;
    return vec3(oneMinusT, oneMinusT, oneMinusT) + b * t;
}


vec3 Albedo(vec2 i_tex)
{
    vec4  texcoords = vec4(i_tex.x, i_tex.y, i_tex.x*_DetailTiling.x, i_tex.y*_DetailTiling.y);
    vec3  albedo = _Color.rgb * texture2D (_MainTex, texcoords.xy).rgb;
#if _DETAIL
    #if (SHADER_TARGET < 30)
        // SM20: instruction count limitation
        // SM20: no detail mask
        float mask = 1;
    #else
        //float mask = DetailMask(texcoords.xy);
        float mask = 1;
    #endif
    
    if( textureSize(_DetailAlbedoMap,0).x > 1 ) {
        vec3 detailAlbedo = texture2D (_DetailAlbedoMap, texcoords.zw).rgb;
        #if _DETAIL_MULX2
            albedo *= LerpWhite2 (detailAlbedo* unity_ColorSpaceDouble.rgb , mask);
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

vec3 Emission(vec2 uv)
{
#ifndef _EMISSION
    return 0;
#else
    return texture2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
#endif
}



inline FragmentCommonData SpecularSetup (vec2 i_tex)
{
    vec4  specGloss  = SpecularGloss(i_tex,_Glossiness);
    vec3  specColor  = specGloss.rgb;    
    float smoothness = specGloss.a;

    _Smoothness = smoothness;

    vec3  albedo = Albedo(i_tex);

    albedo = toLinearAcc(albedo*ALBEDO_SCALE);
    specColor = toLinearAcc(specColor*SPECULAR_SCALE);

    float oneMinusReflectivity;
    vec3  diffColor = EnergyConservationBetweenDiffuseAndSpecular ( albedo , specColor, /*out*/ oneMinusReflectivity);

    FragmentCommonData o = (FragmentCommonData)0;
    o.diffColor = (diffColor);     // diffColor;
    o.specColor = (specColor);     // unity 使用延迟，叠加亮度);
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
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

    FragmentCommonData o = UNITY_SETUP_BRDF_INPUT (i_tex);
    o.normalWorld =  i_normal; 
    o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
    o.posWorld = i_posWorld;

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);

    return o;
}

inline vec3 DecodeHDR (vec4 data, vec4 decodeInstructions)
{
    // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
    float alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;

    // If Linear mode is not supported we can skip exponent part
    #if defined(UNITY_COLORSPACE_GAMMA)
        return (decodeInstructions.x * alpha) * data.rgb;
    #else
    #   if defined(UNITY_USE_NATIVE_HDR)
            return decodeInstructions.x * data.rgb; // Multiplier for future HDRI relative to absolute conversion.
    #   else
            return (decodeInstructions.x * pow(alpha, decodeInstructions.y)) * data.rgb;
    #   endif
    #endif
}

UnityGI FragmentGI(UnityLight light,UnityEnv env)
{
    UnityGI gi;
    gi.light = light;

    vec3 N = env.normal;
    vec3 R = env.refvm;
    vec3 irradiance  = toLinearAcc(textureCubeLod(s_texCube,N, 12).xyz);
    gi.indirect.diffuse = irradiance;

    float roughness = 1 - _Smoothness;
    roughness *= 1.7 - 0.7 * roughness;       // to brightness
    // // prefilter map ,and do not need ambient brdf on mobie ,low cost lod calculate 
    float lod       = 0.1 + 6.0*(roughness);    // this formula close to unity effect 
    vec3  radiance  = toLinearAcc(textureCubeLod(s_texCube, R, lod).xyz);
    //simple, low cost mode 
    // vec3  specular  = radiance*eF; 
    // vec3  color = (diffuse + specular)/(PI);   
    //more accurate, experimal tested 
    gi.indirect.specular = radiance;
    
    return gi;
}

vec4 FogLinear(vec4 color,vec3 camPos,vec3 worldPos,vec4 fogColor,vec4 fogParams)
{
    float fog_coord =  length(camPos-worldPos); 
   float fogFactor = (fogParams.w - fog_coord)/(fogParams.w - fogParams.z);
   fogFactor = clamp( fogFactor, 0.0, 1.0 );
   color = mix(fogColor, color, fogFactor);
   return color;
}


vec4 BRDFSM_Unity_PBS (vec3 diffColor, vec3 specColor, float oneMinusReflectivity, float smoothness,
    vec3 normal, vec3 viewDir,
    UnityLight light, UnityIndirect gi) 
{
    float perceptualRoughness = SmoothnessToPerceptualRoughness (smoothness);
    vec3  V = (viewDir);     // we need pixel 
    vec3  H = Unity_SafeNormalize ( light.dir + V);
    vec3  N = normal; 

#define UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV 0

#if UNITY_HANDLE_CORRECTLY_NEGATIVE_NDOTV
    float  shiftAmount = dot(N, V);
    N = shiftAmount < 0.0f ? N + V * (-shiftAmount + 1e-5f) : N;
    // A re-normalization should be applied here but as the shift is small we don't do it to save ALU.
    //N = normalize(N);
    float NdotV = saturate(dot(N, V));  
#else
    float NdotV = abs(dot(N, V));    // This abs allow to limit artifact
#endif
   
    float NdotL = saturate(dot(N, light.dir));
    float NdotH = saturate(dot(N, H));

    float LdotV = saturate(dot(light.dir, V));
    float LdotH = saturate(dot(light.dir, H));

    float diffuseTerm = DisneyDiffuse(NdotV, NdotL, LdotH, perceptualRoughness) * NdotL;

    float roughness = PerceptualRoughnessToRoughness(perceptualRoughness);
#if UNITY_BRDF_GGX
    // GGX with roughtness to 0 would mean no specular at all, using max(roughness, 0.002) here to match HDrenderloop roughtness remapping.
    roughness = max(roughness, 0.002);

    float G = SmithJointGGXVisibilityTerm (NdotL, NdotV, roughness);
    float D = GGXTerm (NdotH, roughness);
#else
    // Legacy
    float G = SmithBeckmannVisibilityTerm (NdotL, NdotV, roughness);
    float D = NDFBlinnPhongNormalizedTerm (NdotH, PerceptualRoughnessToSpecPower(perceptualRoughness));
#endif

    float specularTerm = D* G * PI;  


#   ifdef UNITY_COLORSPACE_GAMMA
        specularTerm = sqrt(max(1e-4h, specularTerm));
#   endif

    // specularTerm * nl can be NaN on Metal in some cases, use max() to make sure it's a sane value
    specularTerm = max(0, specularTerm * NdotL);

    float surfaceReduction;
#ifdef UNITY_COLORSPACE_GAMMA
        surfaceReduction = 1.0-0.28*roughness*perceptualRoughness;      // 1-0.28*x^3 as approximation for (1/(x^4+1))^(1/2.2) on the domain [0;1]
#else
        surfaceReduction = 1.0 / (roughness*roughness + 1.0);           // fade \in [0.5;1]
#endif
    specularTerm *= any(specColor) ? 1.0 : 0.0;

    float grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
    vec3  grazingColor = vec3(grazingTerm,grazingTerm,grazingTerm);
    vec3  color = diffColor * (gi.diffuse*UNITY_INV_PI + light.color * diffuseTerm)
                  + specularTerm*light.color*FresnelTerm (specColor, LdotH)
                  + surfaceReduction * gi.specular*UNITY_INV_PI * FresnelLerp (specColor, grazingTerm, NdotV );
    return vec4(color,1);
}


inline UnityEnv MainEnv( vec2 st,vec3 camPos, vec3 worldPos,vec3 normal)
{
    UnityEnv env;
    vec3 N = PerPixelWorldNormal( s_normal, st, worldPos, normal  );
    vec3 V = normalize( camPos - worldPos ).xyz;
    vec3 R = reflect(-V, N); 
    env.normal = N;
    env.refvm = R;
    env.viewdir = V;
    return env;
}

void main() 
{   
    ParamsSetup();

    UnityLight light;
    light = MainLight( );

    UnityEnv env;
    env   = MainEnv(  v_texcoord0.xy,v_camPos,v_worldPos,v_normal );

    FragmentCommonData s = FragmentSetup( v_texcoord0.xy, v_viewdir, env.normal, v_worldPos);

    UnityGI gi; 
    gi = FragmentGI(light,env);

    vec4 color = BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, s.eyeVec, gi.light, gi.indirect);
    color.rgb += Emission(  v_texcoord0.xy );
   
    color.rgb = toGammaAcc(color.rgb);
    
    color = FogLinear(color,v_camPos,v_worldPos,_FogColor,_FogParams);
   
    gl_FragColor = vec4( color.rgb , s.alpha ); 
}


