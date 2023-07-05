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
#include "pbr/pbr.sh"
#include "postprocess/tonemapping.sh"
#include "common/default_inputs_structure.sh"
void CUSTOM_FS_FUNC(in FSInput fs_input, inout FSOutput fs_output)
{
#include "pbr/input_attributes.sh"
input_attributes input_attribs = (input_attributes)0;
build_fs_input_attribs(fs_input, input_attribs);

#ifdef MATERIAL_UNLIT
    fs_output.color = mul_inverse_tonemap(input_attribs.basecolor + input_attribs.emissive);
#else //!MATERIAL_UNLIT
    fs_output.color = compute_lighting(input_attribs);
#endif //MATERIAL_UNLIT
}