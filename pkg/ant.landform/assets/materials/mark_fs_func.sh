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
    int mark_type  = (int)fsinput.user0.x;
    const vec2 uv  = fsinput.uv0;
    float mark_alpha = 1 - texture2D(s_alpha, uv).x; 
    vec3 mark_basecolor = calc_mark_basecolor(mark_type);
    fsoutput.color = vec4(mark_basecolor, mark_alpha);
}