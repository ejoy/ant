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
#include "default/inputs_structure.sh"
#include "terrain.sh"

material_info terrain_material_info_init(vec3 gnormal, vec3 normal, vec4 posWS, vec4 basecolor, vec4 fragcoord, vec4 metallic, vec4 roughness)
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

void CUSTOM_FS_FUNC(in FSInput fsinput, inout FSOutput fsoutput)
{
    vec2 terrain_uv    = fsinput.user0.xy;
    vec2 alpha_uv      = fsinput.user0.zw;

    vec4 sand_basecolor    = texture2DArray(s_basecolor_array, vec3(terrain_uv, 0));
    vec4 stone_basecolor   = texture2DArray(s_basecolor_array, vec3(terrain_uv, 1));
    float sand_height   = texture2DArray(s_height, vec3(terrain_uv, 0.0) );
    float stone_height  = texture2DArray(s_height, vec3(terrain_uv, 1.0) );
    float sand_alpha = texture2DArray(s_height, vec3(alpha_uv, 2.0) );

    vec3 terrain_color = blend_terrain_color(sand_basecolor.rgb, stone_basecolor.rgb, sand_height, sand_alpha);

    mat3 tbn = mat3(fsinput.tangent, fsinput.bitangent, fsinput.normal);
    vec3 stone_normal = terrain_normal_from_tangent_frame(tbn, terrain_uv, 1);

    material_info mi = terrain_material_info_init(fsinput.normal, stone_normal, fsinput.pos, vec4(terrain_color, 1.0), fsinput.frag_coord, u_metallic_factor, u_roughness_factor);
    build_material_info(mi);
    fsoutput.color = compute_lighting(mi); 
}