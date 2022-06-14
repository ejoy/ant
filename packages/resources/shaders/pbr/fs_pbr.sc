#include "common/inputs.sh"

$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_BITANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"
#include "common/lighting.sh"
#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/ibl.sh"

#include "pbr/pbr.sh"

#ifdef ENABLE_SHADOW
#include "common/shadow.sh"
#define v_distanceVS v_posWS.w
#endif //ENABLE_SHADOW

// material properites
SAMPLER2D(s_basecolor,          0);
SAMPLER2D(s_metallic_roughness, 1);
SAMPLER2D(s_normal,             2);
SAMPLER2D(s_emissive,           3);
SAMPLER2D(s_occlusion,          4);

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

vec4 get_basecolor(vec2 texcoord, vec4 basecolor)
{
    basecolor *= u_basecolor_factor;
#ifdef HAS_BASECOLOR_TEXTURE
    basecolor *= texture2D(s_basecolor, texcoord);
#endif//HAS_BASECOLOR_TEXTURE
    return basecolor;
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


void get_metallic_roughness(out float metallic, out float roughness, vec2 uv)
{
    metallic = u_metallic_factor;
    roughness = u_roughness_factor;

#ifdef HAS_METALLIC_ROUGHNESS_TEXTURE
    // Roughness is stored in the 'g' channel, metallic is stored in the 'b' channel.
    // This layout intentionally reserves the 'r' channel for (optional) occlusion map data
    vec4 mrSample = texture2D(s_metallic_roughness, uv);
    roughness *= mrSample.g;
    metallic *= mrSample.b;
#endif

    roughness  = clamp(roughness, 0.0, 1.0);
    metallic   = clamp(metallic, 0.0, 1.0);
}

void main()
{
    vec2 uv = uv_motion(v_texcoord0);

    vec4 basecolor = get_basecolor(uv, 
#ifdef WITH_COLOR_ATTRIB
    v_color0);
#else //!WITH_COLOR_ATTRIB
     vec4_splat(1.0));
#endif //WITH_COLOR_ATTRIB

#ifdef ALPHAMODE_OPAQUE
    basecolor.a = u_alpha_mask_cutoff;
#endif //ALPHAMODE_OPAQUE

    vec4 emissivecolor = vec4_splat(0.0);
#ifdef HAS_EMISSIVE_TEXTURE
    emissivecolor = texture2D(s_emissive, uv) * u_emissive_factor;
#endif //HAS_EMISSIVE_TEXTURE

#ifdef MATERIAL_UNLIT
    gl_FragColor = basecolor + emissivecolor;
#else //!MATERIAL_UNLIT

    vec3 posWS = v_posWS.xyz;
    vec3 V = normalize(u_eyepos.xyz - posWS);
#   ifdef WITH_TANGENT_ATTRIB
    vec3 N = get_normal(v_tangent, v_bitangent, v_normal, uv);
#   else //!WITH_TANGENT_ATTRIB
    vec3 N = get_normal_by_tbn(tbn_from_world_pos(v_normal, posWS, uv), v_normal, uv);
#   endif //WITH_TANGENT_ATTRIB

    float metallic, roughness;
    get_metallic_roughness(metallic, roughness, uv);
    material_info mi = init_material_info(metallic, roughness, basecolor, N, V);

    // LIGHTING
    vec3 color = calc_direct_light(mi, gl_FragCoord, posWS);

#   ifdef ENABLE_SHADOW
	color = shadow_visibility(v_distanceVS, vec4(posWS, 1.0), color);
#   endif //ENABLE_SHADOW

#   ifdef ENABLE_IBL
    color += calc_indirect_light(mi);
#   endif //ENABLE_IBL

#   ifdef HAS_OCCLUSION_TEXTURE
    float ao = texture2D(s_occlusion,  uv).r;
    color  += lerp(color, color * ao, u_occlusion_strength);
#   endif //HAS_OCCLUSION_TEXTURE

#   ifdef ALPHAMODE_MASK
    // Late discard to avoid samplig artifacts. See https://github.com/KhronosGroup/glTF-Sample-Viewer/issues/267
    if(color.a < u_alpha_mask_cutoff)
        discard;
    color.a = 1.0;
#   endif //ALPHAMODE_MASK

    gl_FragColor = vec4(color, basecolor.a) + emissivecolor;
#endif //MATERIAL_UNLIT


}
