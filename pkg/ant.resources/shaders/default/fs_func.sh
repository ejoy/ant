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

//TODO: move to pbr folder
void CUSTOM_FS_FUNC(in FSInput input, inout FSOutput output)
{
    material_info mi = (material_info)0;
    init_material_info(input, mi);
#ifdef MATERIAL_UNLIT
    output.color = mul_inverse_tonemap(mi.basecolor + mi.emissive);
#else //!MATERIAL_UNLIT
    build_material_info(mi);
    output.color = compute_lighting(mi);
#endif //MATERIAL_UNLIT
}