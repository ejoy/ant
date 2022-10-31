#ifndef _PBR_INPUT_ATTRIBUTES_SH_
#define _PBR_INPUT_ATTRIBUTES_SH_

// material properites
#ifdef HAS_BASECOLOR_TEXTURE
SAMPLER2D(s_basecolor,          0);
#endif //HAS_BASECOLOR_TEXTURE

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
SAMPLER2D(s_metallic_roughness, 1);
#endif //HAS_METALLIC_ROUGHNESS_TEXTURE

#ifdef HAS_NORMAL_TEXTURE
SAMPLER2D(s_normal,             2);
#endif //HAS_NORMAL_TEXTURE

#ifdef HAS_EMISSIVE_TEXTURE
SAMPLER2D(s_emissive,           3);
#endif //HAS_EMISSIVE_TEXTURE

#ifdef HAS_OCCLUSION_TEXTURE
SAMPLER2D(s_occlusion,          4);
#endif //HAS_OCCLUSION_TEXTURE

#ifdef USING_LIGHTMAP
SAMPLER2D(s_lightmap,           8);
#endif //USING_LIGHTMAP

uniform vec4 u_basecolor_factor;
uniform vec4 u_emissive_factor;
uniform vec4 u_pbr_factor;
#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

struct input_attributes
{
    vec4 basecolor;
    vec4 emissive;

    vec3 N;
    float metallic;

    vec3 V;
    float perceptual_roughness;

    vec3 pos;
    float occlusion;

    vec2 uv;
    vec2 screen_uv;
#ifdef ENABLE_BENT_NORMAL
    // this bent normal is pixel bent normal in world space
    vec3 bent_normal;
#endif //ENABLE_BENT_NORMAL
};

vec4 get_basecolor(vec2 texcoord, vec4 basecolor)
{
    basecolor *= u_basecolor_factor;
#ifdef HAS_BASECOLOR_TEXTURE
    basecolor *= texture2D(s_basecolor, texcoord);
#endif//HAS_BASECOLOR_TEXTURE

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif //ALPHAMODE_OPAQUE
    return basecolor;
}

vec4 get_emissive_color(vec2 texcoord)
{
    vec4 emissivecolor = u_emissive_factor;
#ifdef HAS_EMISSIVE_TEXTURE
    emissivecolor *= texture2D(s_emissive, texcoord);
#endif //HAS_EMISSIVE_TEXTURE
    return emissivecolor;
}

vec3 get_normal_by_tbn(mat3 tbn, vec3 normal, vec2 texcoord)
{
#ifdef HAS_NORMAL_TEXTURE
	vec3 normalTS = fetch_bc5_normal(s_normal, texcoord);
	return normalize(instMul(normalTS, tbn));
#else //!HAS_NORMAL_TEXTURE
    return normal;
#endif //HAS_NORMAL_TEXTURE
}

vec3 get_normal(vec3 tangent, vec3 bitangent, vec3 normal, vec2 texcoord)
{
    mat3 tbn = mtxFromCols(tangent, bitangent, normal);
    return get_normal_by_tbn(tbn, normal, texcoord);
}


void get_metallic_roughness(vec2 uv, inout input_attributes input_attribs)
{
    input_attribs.metallic = u_metallic_factor;
    input_attribs.perceptual_roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    vec4 mrSample = texture2D(s_metallic_roughness, uv);
    input_attribs.perceptual_roughness *= mrSample.g;
    input_attribs.metallic *= mrSample.b;
#endif //HAS_METALLIC_ROUGHNESS_TEXTURE

    input_attribs.perceptual_roughness  = clamp(input_attribs.perceptual_roughness, 0.0, 1.0);
    input_attribs.metallic              = clamp(input_attribs.metallic, 0.0, 1.0);
}

void get_occlusion(vec2 uv, inout input_attributes input_attribs)
{
#ifdef HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = texture2D(s_occlusion,  uv).r;
#else //!HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = 1.0;
#endif //HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion *= u_occlusion_strength;
}

#endif //_PBR_INPUT_ATTRIBUTES_SH_