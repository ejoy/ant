#ifndef _PBR_COMMON_SH_
#define _PBR_COMMON_SH_

/*
    half reflectance is: 0.5
    dielectric F0 = 0.16 * half_reflectance * half_reflectance = 0.04
*/
#define MIN_ROUGHNESS 0.04
#define MIN_REFLECTANCE MIN_ROUGHNESS

#endif //_PBR_COMMON_SH_