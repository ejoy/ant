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
#include "default/inputs_structure.sh"
#include "road.sh"


void CUSTOM_FS_FUNC(in FSInput fsinput, inout FSOutput fsoutput)
{
    int road_type  = (int)fsinput.user0.x;
    const vec2 uv  = fsinput.uv0;

    vec4 road_basecolor = texture2D(s_basecolor, uv); 

    vec3 basecolor = calc_road_basecolor(road_basecolor.rgb, road_type);

    mediump vec4 mrSample = texture2D(s_metallic_roughness, uv);
    float roughness = mrSample.g;
    float metallic = mrSample.b;
    material_info mi = road_material_info_init(fsinput.normal, fsinput.normal, fsinput.pos, vec4(basecolor, road_basecolor.a), fsinput.frag_coord, metallic, roughness);
    build_material_info(mi);
    fsoutput.color = compute_lighting(mi);
}