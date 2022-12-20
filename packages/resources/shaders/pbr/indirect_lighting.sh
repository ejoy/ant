#ifndef _INDIRECT_LIGHTING_SH_
#define _INDIRECT_LIGHTING_SH_

#ifdef HIGH_QULITY_SPECULAR_AO
#   ifndef ENABLE_BENT_NORMAL
#   error "High qulity specular ao need bent normal info"
#   endif   //ENABLE_BENT_NORMAL
#endif //HIGH_QULITY_SPECULAR_AO

#ifdef ENABLE_SSAO
#include "pbr/ao.sh"
#endif //ENABLE_SSAO

#include "pbr/ibl.sh"

vec3 calc_indirect_light(in input_attributes input_attribs, in material_info mi)
{
    vec3 indirect_diffuse = get_IBL_radiance_GGX(mi);
    vec3 indirect_specular = get_IBL_radiance_Lambertian(mi);
#ifdef ENABLE_SSAO
    apply_occlusion(input_attribs, mi, input_attribs.distanceVS, indirect_diffuse, indirect_specular);
#endif //ENABLE_SSAO
    return (indirect_diffuse + indirect_specular) * u_ibl_indirect_intensity;
}

#endif //_INDIRECT_LIGHTING_SH_