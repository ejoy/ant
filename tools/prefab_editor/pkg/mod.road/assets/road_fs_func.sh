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
#include "road.sh"
#include "pbr/input_attributes.sh"

void CUSTOM_FS_FUNC(in FSInput fs_input, inout FSOutput fs_output)
{
    float road_type  = fs_input.user0.x;
    float road_shape = fs_input.user0.y;
    float mark_type  = fs_input.user0.z;
    float mark_shape = fs_input.user0.w;

	//t0 1x1 road color/height/normal
	//t1 1x1 mark color/alpha
    const vec2 road_uv  = fs_input.uv0;
    const vec2 mark_uv  = fs_input.user1.xy;

    vec4 road_basecolor = texture2D(s_basecolor, vec3(road_uv, road_shape));

    vec4 mark_basecolor = vec4(0, 0, 0, 0);
    float mark_alpha = 0;
    
    if(mark_type != 0){
        mark_alpha = texture2DArray(s_mark_alpha, vec3(mark_uv, mark_shape));
        if(mark_type == 1){
            mark_basecolor = vec4(0.71484, 0, 0, 1);
        }
        else{
            mark_basecolor = vec4(1, 1, 1, 1);
        }
    }   

    vec3 basecolor = calc_road_mark_blend_color(road_type, road_basecolor, mark_type, mark_basecolor, mark_alpha);

    bool is_road_part = road_type != 0;
    bool is_mark_part = mark_type != 0;
    if(is_road_part && !is_mark_part && road_basecolor.a == 0){
        discard;
    }
    else if(!is_road_part && is_mark_part && mark_alpha == 1){
        discard;
    }
    else if(is_road_part && is_mark_part && road_basecolor.a == 0 && mark_alpha == 1){
        discard;
    }
    else{
        mediump vec4 mrSample = texture2D(s_metallic_roughness, road_uv);
        float roughness = mrSample.g;
        float metallic = mrSample.b;
        input_attributes input_attribs = init_input_attributes(fs_input.normal, fs_input.normal, fs_input.pos, vec4(basecolor, 1.0), fs_input.frag_coord, metallic, roughness);
        fs_output.color = compute_lighting(input_attribs);
    }
}