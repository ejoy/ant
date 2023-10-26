#ifndef _PBR_COMMON_SH_
#define _PBR_COMMON_SH_

/*
    half reflectance is: 0.5
    dielectric F0 = 0.16 * half_reflectance * half_reflectance = 0.04
*/
#define MIN_ROUGHNESS 0.04
#define MIN_REFLECTANCE MIN_ROUGHNESS

#define u_metallic_factor    u_pbr_factor.x
#define u_roughness_factor   u_pbr_factor.y
#define u_alpha_mask_cutoff  u_pbr_factor.z
#define u_occlusion_strength u_pbr_factor.w

#endif //_PBR_COMMON_SH_