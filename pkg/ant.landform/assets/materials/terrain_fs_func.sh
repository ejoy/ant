#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"
#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/common.sh"
#include "pbr/lighting.sh"
#include "pbr/material_info.sh"

material_info terrain_material_info_init(vec3 gnormal, vec3 normal, vec4 posWS, vec4 basecolor, vec4 fragcoord, float metallic, float roughness)
{
    material_info mi  = (material_info)0;
    mi.basecolor         = basecolor;
    mi.posWS             = posWS.xyz;
    mi.distanceVS        = posWS.w;
    mi.V                 = normalize(u_eyepos.xyz - posWS.xyz);
    mi.gN                = gnormal;  //geomtery normal
    mi.N                 = normal;

    mi.perceptual_roughness  = roughness;
    mi.metallic          = metallic;
    mi.occlusion         = 1.0;

    mi.screen_uv         = calc_normalize_fragcoord(fragcoord.xy);
    return mi;
}

vec3 blend_terrain_color(vec3 sand_basecolor, vec3 stone_basecolor, float sand_height, float sand_alpha)
{
    float sand_weight = min(1.0, 2.5 * abs(sand_height - sand_alpha));
	return lerp(stone_basecolor, sand_basecolor, sand_weight);
}

mediump vec3 terrain_normal_from_tangent_frame(mat3 tbn, vec3 texcoord)
{
    vec3 normalTS = fetch_normal_from_tex_array(s_normal_array, texcoord);
    return transform_normal_from_tbn(tbn, normalTS);
}


void CUSTOM_FS(in Varyings varyings, out FSOutput fsoutput)
{
    vec2 terrain_uv    = varyings.texcoord0.xy;
    vec2 alpha_uv      = varyings.texcoord0.zw;

    vec4 sand_basecolor = texture2DArray(s_basecolor_array, vec3(terrain_uv, 0.0));
    vec4 stone_basecolor= texture2DArray(s_basecolor_array, vec3(terrain_uv, 1.0));

    float sand_height   = texture2DArray(s_height, vec3(terrain_uv, 0.0)).r;
    float stone_height  = texture2DArray(s_height, vec3(terrain_uv, 1.0)).r;
    float sand_alpha    = texture2DArray(s_height, vec3(alpha_uv,   2.0)).r;

    vec3 terrain_color = blend_terrain_color(sand_basecolor.rgb, stone_basecolor.rgb, sand_height, sand_alpha);

    mat3 tbn = mat3(varyings.tangent, varyings.bitangent, varyings.normal);
    vec3 stone_normal = terrain_normal_from_tangent_frame(tbn, vec3(terrain_uv, 1.0));

    material_info mi = terrain_material_info_init(varyings.normal, stone_normal, varyings.posWS, vec4(terrain_color, 1.0), varyings.frag_coord, u_metallic_factor, u_roughness_factor);
    build_material_info(mi);
    fsoutput.color = compute_lighting(mi); 
}