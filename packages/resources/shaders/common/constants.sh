#ifndef _CONSTANTS_SH_
#define _CONSTANTS_SH_

#define PI                  M_PI
#define PI2                 6.283185307
#define PI_2                1.570796327
#define PI_4                0.7853981635
#define INV_PI              0.318309886
#define INV_PI2             0.159154943

#define FP16Scale           0.0009765625

#define HALF_PI             1.570796327

#define MEDIUMP_FLT_MAX     65504.0
#define MEDIUMP_FLT_MIN     0.00006103515625

#ifdef TARGET_MOBILE
#define FLT_EPS             MEDIUMP_FLT_MIN
#else   //TARGET_MOBILE
#define FLT_EPS             1e-5
#endif //TARGET_MOBILE

#endif //_CONSTANTS_SH_