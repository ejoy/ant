#ifndef _TERRAIN_INPUT_ATTRIBUTES_SH_
#define _TERRAIN_INPUT_ATTRIBUTES_SH_

SAMPLER2D(s_stone1_color,          0);
SAMPLER2D(s_stone2_color,          1);
SAMPLER2D(s_sand1_color,           2);
SAMPLER2D(s_sand2_color,           3);
SAMPLER2D(s_sand3_color,           4);
SAMPLER2D(s_stone_height,          5);
SAMPLER2D(s_sand_height,           6);
SAMPLER2D(s_stone1_normal,         7);
SAMPLER2D(s_stone2_normal,         8);
SAMPLER2D(s_sand_normal,           9);

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

    float occlusion;
    float occlusion_strength;
    vec2 uv;

    vec3 pos;
};

vec3 get_V(vec3 eyePos, vec3 posWS)
{
    return normalize(eyePos - posWS);
}


vec4 get_emissive_color(vec2 texcoord)
{
    vec4 emissivecolor = u_emissive_factor;
#ifdef HAS_EMISSIVE_TEXTURE
    emissivecolor *= texture2D(s_emissive, texcoord);
#endif //HAS_EMISSIVE_TEXTURE
    return emissivecolor;
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

void get_occlusion(vec2 texcoord, inout input_attributes input_attribs)
{
#ifdef HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = texture2D(s_occlusion,  uv).r;
#else
    input_attribs.occlusion = 1.0;
#   endif //HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion_strength = u_occlusion_strength;
}

vec3 apply_occlusion(input_attributes input_attribs, vec3 color)
{
    #ifdef HAS_OCCLUSION_TEXTURE
    color  += lerp(color, color * input_attribus.occlusion, input_attribus.occlusion_strength);
    #endif //HAS_OCCLUSION_TEXTURE
    return color;
}

#endif //_TERRAIN_INPUT_ATTRIBUTES_SH_