#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"
#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/lighting.sh"
#include "pbr/attribute_define.sh"
#include "pbr/attribute_uniforms.sh"
#include "common/default_inputs_structure.sh"
#include "pbr/input_attributes.sh"
#include "terrain.sh"

uniform vec4 u_metallic_roughness_factor1;
uniform vec4 u_metallic_roughness_factor2;

#define u_stone_metallic_factor     u_metallic_roughness_factor1.z
#define u_stone_roughness_factor    u_metallic_roughness_factor1.w


void CUSTOM_FS_FUNC(in FSInput fs_input, inout FSOutput fs_output)
{
    float sand_color_idx  = fs_input.user0.x;
    float stone_color_idx = fs_input.user0.y;
    vec2 terrain_uv    = fs_input.uv0;
    vec2 alpha_uv      = fs_input.user1.xy;

    vec4 stone_basecolor   = texture2DArray(s_basecolor_array, vec3(terrain_uv, stone_color_idx));
    vec4 sand_basecolor    = texture2DArray(s_basecolor_array, vec3(terrain_uv, sand_color_idx));
    float sand_height   = texture2DArray(s_height, vec3(terrain_uv, 0.0) );
    float stone_height  = texture2DArray(s_height, vec3(terrain_uv, 1.0) );
    float sand_alpha = texture2DArray(s_height, vec3(alpha_uv, 2.0) );

    vec3 terrain_color = blend_terrain_color(sand_basecolor.rgb, stone_basecolor.rgb, sand_height, sand_alpha);

    fs_input.normal = normalize(fs_input.normal);
    fs_input.tangent = normalize(fs_input.tangent);
    vec3 bitangent = cross(fs_input.normal, fs_input.tangent);
    mat3 tbn = mat3(fs_input.tangent, bitangent, fs_input.normal);
    vec3 stone_normal = terrain_normal_from_tangent_frame(tbn, terrain_uv, 1);
    float roughness = u_stone_roughness_factor;
    float metallic = u_stone_metallic_factor;
    input_attributes input_attribs = init_input_attributes(fs_input.normal, stone_normal, fs_input.pos, vec4(terrain_color, 1.0), fs_input.frag_coord, metallic, roughness);
    fs_output.color = compute_lighting(input_attribs); 
}