#define  PI  3.14159265359f

// Walter GGX + Smith G + BlinnSchlick 
// Lambertian balanced 

vec3 getNormalFromMap( sampler2D normalMap, vec2 texCoords, vec3 worldPos, vec3 normal)
{
    //return normal; 
    vec3 tangentNormal = texture2D(normalMap, texCoords).xyz * 2.0 - 1.0;

    vec3 Q1  = ddx(worldPos);
    vec3 Q2  = ddy(worldPos);
    vec2 st1 = ddx(texCoords);
    vec2 st2 = ddy(texCoords);

    vec3 N   = normalize(normal);
    vec3 T  = normalize(Q1*st2.y - Q2*st1.y);
    vec3 B  = -normalize(cross(N, T));
    mat3 TBN = mat3(T, B, N);

    // D3D Mode ,OpenGL Must do transpose 
    tangentNormal = mul( tangentNormal,TBN  ) ;
    return normalize(tangentNormal);
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
float GeometrySchlickGGX(float NdotV, float roughness)
{
    float r = (roughness + 1.0);
    float k = (r*r) / 4.0;
    //float k= 2/sqrt(PI*(r+2));  //more expensive ，make it simple 

    float nom   = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / max(denom,1e-6);
}

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

// ----------------------------------------------------------------------------
float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness)
{
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);

    float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
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


// ----------------------------------------------------------------------------
vec3 fresnelSchlick(float cosTheta, vec3 F0)
{
    //F(l,h) = rf0 + (1-rf0)(1-h.l)^5 
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

vec3 fresnelSchlickRoughness(float ndotv, vec3 F0,float roughness)
{
    return F0 + (1.0 - F0) * pow(1.0 - ndotv, 5.0)*roughness;
}

#define vec3_c(v) vec3(v,v,v)
// no micro facet D,so use ntov and roughness experience mode
vec3 fresnelSchlickRoughness2(float ndotv, vec3 F0, float roughness)
{
     vec3 rough = vec3_c(1.0-roughness);
     return F0 + (max(rough,F0)-F0)*pow(1.0-ndotv,5.0);
} 

float fresnelNV(float ndotv, float power,  float scale,  float bias)
{
    return bias + (pow(clamp(1.0 - ndotv, 0.0, 1.0), power) * scale);
}

// -----------------------------------------------------------------------------
// simple tonemapping,if you wanna diff effect,could change and  extend this function 
vec3 toneMapping(vec3 color) 
{
    return color / (color + vec3_c(1.0) );
}




