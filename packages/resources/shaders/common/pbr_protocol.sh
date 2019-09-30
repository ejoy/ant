#include "common/transform.sh"
#define  PI  3.14159265359f

// Walter GGX + Smith G + BlinnSchlick 
// Lambertian balanced 

float RecalcDXTNormalZ(vec2 normalXY)
{
    return sqrt(1.0 - saturate(dot(normalXY, normalXY)));
}

vec3 RemapDXTNormalValue(vec2 normalTSXY, float offset)
{
    vec2 normalTSXY_Remap = normalTSXY * 2.0 - 1.0;
    normalTSXY_Remap = normalTSXY_Remap * offset;
    return vec3(normalTSXY_Remap, RecalcDXTNormalZ(normalTSXY_Remap));
}

vec3 FetchCompressNormalMapValue(sampler2D normalMap, vec2 texcoord, float offset)
{
    return RemapDXTNormalValue(texture2D(normalMap, texcoord).xy, offset);
}

vec3 UnpackNormalDXTnm(vec4 packednormal)
{
    return RemapDXTNormalValue(packednormal.wy, 1.0);
}

// very heary operation to calculate tbn matrix in framgent shader. 
// we already have some option to calculate tangent and bitangent vector when import mesh.
vec3 getWorldSpcaeNormalFromTexture(sampler2D normalMap, vec2 texCoords, vec3 worldPos, vec3 vertexNormal)
{
    vec3 normalTS = FetchCompressNormalMapValue(normalMap, texCoords, 1.2);
    mat3 TBN = tbn_from_world_pos(vertexNormal, worldPos, texCoords);

    return normalize(mul(normalTS, TBN));
}

half3 BlendNormals(half3 n1, half3 n2)
{
    return normalize(half3(n1.xy + n2.xy, n1.z*n2.z));
}


vec3 PixelNormalMap(vec3 normal, sampler2D detailNormalMap, vec2 texCoords)
{
#ifdef _DETAIL 
    if( textureSize(detailNormalMap,0).x > 1 )
    {
        float mask =  1.0;
        vec3 detailNormal = texture2D(detailNormalMap, texCoords).xyz* 2.0 - 1.0;
        detailNormal = detailNormal*_DetailNormalMapScale;

        #ifndef _DETAIL_LERP
        detailNormal = BlendNormals(normal, detailNormal);
        #endif

        return lerp(normal, detailNormal, mask);
    }
#endif 

    return normal;    
}

vec3 getPixelNormalFromMap( sampler2D normalMap, vec2 texCoords, vec3 worldPos, vec3 normal)
{
    vec3 normalWS = getWorldSpcaeNormalFromTexture(normalMap,texCoords,worldPos,normal);
#ifdef _DETAIL
    return PixelNormalMap(normalWS,_DetailNormalMap,texCoords*_DetailTiling);
#else
    return normalWS;
#endif 
}

// ----------------------------------------------------------------------------
// from Walter 
float DistributionGGX(vec3 N, vec3 H, float roughness)
{
    float a = roughness*roughness;
    float a2 = a*a;                 // a will decentralized fast 
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH*NdotH;

    float nom   = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / max(denom,1e-6);
}


// ----------------------------------------------------------------------------


float BrdfDenominatorStd(float NdotV,float NdotL) 
{
    return 4 * max(NdotV, 0.0) * max(NdotL, 0.0) + 1e-6;
}


float BrdfDenominatorOpt(float NdotV,float NdotL,float roughness) {
    float a = roughness;
    float a2 = a*a;
    float G_V = NdotV + sqrt( (NdotV - NdotV * a2) * NdotV + a2 );
    float G_L = NdotL + sqrt( (NdotL - NdotL * a2) * NdotL + a2 );
    return 1/ ( G_V * G_L );
}

//--------------------------------

float G1GGX(vec3 v, vec3 h, float a)
{
    float NdotV = max(dot(v, h),0);
    float a2 = a * a;

    return (2.0f * NdotV) / max(NdotV + sqrt(a2 + (1.0f - a2) * NdotV * NdotV), 1e-6f);
}

float GeometryGGX(vec3 n, vec3 v, vec3 l, vec3 h, float roughness)
{
    return G1GGX(v, h, roughness) * G1GGX(l, h, roughness);
}

// ----------------------------------------------------------------------------
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    //float k= 2/sqrt(PI*(r+2));  //more expensive ，make it simple 
    float k = (r*r) / 4.0;

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / max(denom,1e-6);
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    //return GeometryGGX(N,V,L,roughness);

    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);

    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}



// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    //F(l,h) = rf0 + (1-rf0)(1-h.l)^5   
    //return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
    return F0 + (1.0 - F0) * exp2(-8.35 * cosTheta);
}

vec3 fresnelSchlickRoughness(float cosTheta, vec3 F0,float roughness)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0)*roughness;
}


#define vec3_c(v) vec3(v,v,v)
 
vec3 fresnelSchlickRoughness2(float cosTheta, vec3 F0, float roughness)
{
    float rough = 1.0-roughness;
    return F0 + (max(vec3_c(rough),F0)-F0)*pow(1.0-cosTheta,5.0);
} 


vec3 BlinnSchlick(vec3 _cspec, float _ndoth, float _ndotl, float _specPwr)
{
	float norm = (_specPwr+8.0)*0.125;
	float brdf = pow(_ndoth, _specPwr)*_ndotl*norm;
	return _cspec*brdf;
}

float specPwr(float _gloss)
{
	return exp2(10.0*_gloss+2.0);
}
// -----------------------------------------------------------------------------
// simple tonemapping,if you wanna diff effect,could change and  extend this function 
vec3 toneMapping(vec3 color,float exposure) 
{
    return color / (color + vec3_c(exposure) );
   //return vec3_c(1.0) - exp(-color * exposure);
}

     


