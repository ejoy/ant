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
#include "pbr/indirect_lighting.sh"
#include "postprocess/tonemapping.sh"
#include "default/inputs_structure.sh"
#include "pbr/material_info.sh"
#include "pbr/material_default.sh"

vec2 parallax_mapping(vec2 uv, vec3 view_dir, float num_layers)
{
    float layer_height = 1.0 / num_layers;
    float current_layer_height = 0.0;
    vec2 P = view_dir.xy * 0.1;
    vec2 delta_uv = P / num_layers;
    vec2 current_uv = uv;
    float current_height = texture2D(s_height, current_uv).r;
    for(int i = 0; i < num_layers; ++i){
        current_uv -= delta_uv;
        current_height = texture2D(s_height, current_uv).r;
        current_layer_height += layer_height;
        if(current_layer_height >= current_height){
            break;
        }
    }

    return current_uv;
/*     vec2 prev_uv = current_uv + delta_uv;
    float after_height = current_height - current_layer_height;
    float before_height = texture2D(s_height, current_uv).r - current_layer_height + layer_height;
    float weight = after_height / (after_height - before_height);
    vec2 final_uv = prev_uv * weight + current_uv * (1.0 - weight);
    return final_uv; 
 */
/*     float height = texture2D(s_height, uv).r;
    vec2 p = view_dir.xy / view_dir.z * (height * 0.1);
    return uv - p; */
}

void CUSTOM_FS_FUNC(in FSInput fsinput, inout FSOutput fsoutput)
{
    material_info mi = (material_info)0;
    default_init_material_info(fsinput, mi);

    // remember that, this tbn is transposed, so, all the transform: mul(tbn, v), should convert to: mul(v, tbn), same with mul(transpose(tbn), v)
    mat3 tbn = mat3(mi.T, mi.B, mi.gN);

    //view_dir is same with: mul(mi.V, tbn)
    vec3 tangent_view = mul(u_eyepos.xyz, tbn);
    vec3 tangent_pos  = mul(fsinput.pos.xyz, tbn);
    vec3 view_dir = normalize(tangent_view - tangent_pos);
    float min_layers = 8.0;
    float max_layers = 32.0;

    //TODO: transform tangent space vec3(0, 0, 1) to worldspace Z can simplify 'num_layers' calculation, and Z is inverse tbn's three column, mean's: Z = transpose(tbn)[2]
    float num_layers = mix(max_layers, min_layers, max(dot(vec3(0, 0, 1), view_dir), 0));
    vec2 uv = parallax_mapping(fsinput.uv0, view_dir, num_layers);
    if(uv.x > 1.0 || uv.y > 1.0 || uv.x < 0.0 || uv.y < 0.0){
        discard;
    }

    build_material_info(mi);

    fsoutput.color = compute_lighting(mi);
}