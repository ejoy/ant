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
    float mark_alpha = texture2D(s_basecolor, fsinput.uv0).r;
    fsoutput.color = vec4(fsinput.color.rgb, mark_alpha);
}