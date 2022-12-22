#ifndef _PBR_INPUT_ATTRIBUTES_SH_
#define _PBR_INPUT_ATTRIBUTES_SH_

// material properites
#ifdef HAS_BASECOLOR_TEXTURE
lowp SAMPLER2D(s_basecolor,          0);
#endif //HAS_BASECOLOR_TEXTURE

#ifdef HAS_TERRAIN_BASECOLOR_TEXTURE
lowp SAMPLER2DARRAY(s_basecolor,          0);
#endif //HAS_TERRAIN_BASECOLOR_TEXTURE

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
mediump SAMPLER2D(s_metallic_roughness, 1);
#endif //HAS_METALLIC_ROUGHNESS_TEXTURE

#ifdef HAS_NORMAL_TEXTURE
mediump SAMPLER2D(s_normal,             2);
#endif //HAS_NORMAL_TEXTURE

#ifdef HAS_TERRAIN_NORMAL_TEXTURE
mediump SAMPLER2DARRAY(s_normal,             2);
#endif //HAS_TERRAIN_NORMAL_TEXTURE

#ifdef HAS_EMISSIVE_TEXTURE
mediump SAMPLER2D(s_emissive,           3);
#endif //HAS_EMISSIVE_TEXTURE

#ifdef HAS_OCCLUSION_TEXTURE
mediump SAMPLER2D(s_occlusion,          4);
#endif //HAS_OCCLUSION_TEXTURE

#ifdef USING_LIGHTMAP
mediump SAMPLER2D(s_lightmap,           8);
#endif //USING_LIGHTMAP

uniform mediump vec4 u_basecolor_factor;
uniform mediump vec4 u_emissive_factor;
uniform mediump vec4 u_pbr_factor;
#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

struct input_attributes
{
    lowp vec4 basecolor;
    mediump vec4 emissive;

    mediump vec3 N;
    mediump float metallic;

    mediump vec3 V;
    mediump float perceptual_roughness;

    mediump vec3 pos;
    mediump float occlusion;

    mediump vec2 uv;
    mediump vec2 screen_uv;

    mediump vec3 posWS;
    mediump float distanceVS;
    mediump vec4 fragcoord;
    mediump vec3 gN;

#ifdef ENABLE_BENT_NORMAL
    // this bent normal is pixel bent normal in world space
    mediump vec3 bent_normal;
#endif //ENABLE_BENT_NORMAL

#ifdef USING_LIGHTMAP
    mediump vec2 uv1;
#endif //USING_LIGHTMAP
};

mediump vec4 get_basecolor(mediump vec2 texcoord, mediump vec4 basecolor)
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

mediump vec4 get_terrain_basecolor(mediump vec2 texcoord, mediump vec4 basecolor, mediump float color_idx)
{
    basecolor *= u_basecolor_factor;

#ifdef HAS_TERRAIN_BASECOLOR_TEXTURE
    basecolor *= texture2DArray(s_basecolor, mediump vec3(texcoord, color_idx) );
#endif//HAS_TERRAIN_BASECOLOR_TEXTURE

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif //ALPHAMODE_OPAQUE
    return basecolor;
}


mediump vec4 get_emissive_color(mediump vec2 texcoord)
{
    mediump vec4 emissivecolor = u_emissive_factor;
#ifdef HAS_EMISSIVE_TEXTURE
    emissivecolor *= texture2D(s_emissive, texcoord);
#endif //HAS_EMISSIVE_TEXTURE
    return emissivecolor;
}

mediump vec3 remap_normal(mediump vec2 normalTSXY)
{
    mediump vec2 normalXY = normalTSXY * 2.0 - 1.0;
	mediump float z = sqrt(1.0 - dot(normalXY, normalXY));
    return mediump vec3(normalXY, z);
}

mediump vec3 fetch_bc5_normal(sampler2D normalMap, mediump vec2 texcoord)
{
    return remap_normal(texture2DBc5(normalMap, texcoord));
}

#ifdef HAS_NORMAL_TEXTURE
mediump vec3 normal_from_tangent_frame(mat3 tbn, mediump vec2 texcoord)
{
	mediump vec3 normalTS = fetch_bc5_normal(s_normal, texcoord);
    // same as: mul(transpose(tbn), normalTS)
    return normalize(mul(normalTS, tbn));
}
#endif //HAS_NORMAL_TEXTURE

mediump vec3 get_terrain_normal_by_tbn(mat3 tbn, mediump vec3 normal, mediump vec2 texcoord, mediump float normal_idx)
{
#ifdef HAS_TERRAIN_NORMAL_TEXTURE
	mediump vec3 normalTS = texture2DArray(s_normal, mediump vec3(texcoord, normal_idx) );
	return normalize(instMul(normalTS, tbn));
#endif //HAS_TERRAIN_NORMAL_TEXTURE
    return normal;
}

void get_metallic_roughness(mediump vec2 uv, inout input_attributes input_attribs)
{
    input_attribs.metallic = u_metallic_factor;
    input_attribs.perceptual_roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    mediump vec4 mrSample = texture2D(s_metallic_roughness, uv);
    input_attribs.perceptual_roughness *= mrSample.g;
    input_attribs.metallic *= mrSample.b;
#endif //HAS_METALLIC_ROUGHNESS_TEXTURE

    input_attribs.perceptual_roughness  = clamp(input_attribs.perceptual_roughness, 0.0, 1.0);
    input_attribs.metallic              = clamp(input_attribs.metallic, 0.0, 1.0);
}

void get_occlusion(mediump vec2 uv, inout input_attributes input_attribs)
{
#ifdef HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = texture2D(s_occlusion,  uv).r;
#else //!HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion = 1.0;
#endif //HAS_OCCLUSION_TEXTURE
    input_attribs.occlusion *= u_occlusion_strength;
}

#endif //_PBR_INPUT_ATTRIBUTES_SH_