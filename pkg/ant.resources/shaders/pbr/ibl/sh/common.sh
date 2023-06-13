#ifndef __SH_COMMON_SH__
#define __SH_COMMON_SH__

#ifndef IRRADIANCE_SH_BAND_NUM
#define IRRADIANCE_SH_BAND_NUM 2
#endif //IRRADIANCE_SH_BAND_NUM

#define IRRADIANCE_SH_COEFF_NUM (IRRADIANCE_SH_BAND_NUM*IRRADIANCE_SH_BAND_NUM)

uniform vec4 u_build_SH_param;
#define u_facesize  u_build_SH_param.x
#define u_lod       u_build_SH_param.y
#endif //__SH_COMMON_SH__