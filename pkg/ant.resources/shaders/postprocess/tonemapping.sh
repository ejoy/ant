#ifndef _TONEMAPPING_
#define _TONEMAPPING_

#include "common/constants.sh"
#include "common/postprocess.sh"
//#include "exposure.sh"
#include "aces.sh"

vec3 inverse_tonemap_Filmic(vec3 c)
{
    return (0.03 - 0.59 * c - sqrt(0.0009 + 1.3702 * c - 1.0127 * c * c)) / (-5.02 + 4.86 * c);
}

vec4 mul_inverse_tonemap(vec4 c)
{
#ifdef UNLIT_INVERSE_TONEMAP
    //TODO: need to use ACESFitted inverse tonemap, temporary fix inverse tonemap
    return vec4(inverse_tonemap_Filmic(c.rgb), c.a);
#else  //!UNLIT_INVERSE_TONEMAP
    return c;
#endif //UNLIT_INVERSE_TONEMAP
}

vec3 tonemapping(in vec3 color, float avg_luminance, float offset)
{
//     float exposure = 
// #if EXPOSURE_TYPE == AUTO_EXPOSURE 
//     calc_auto_exposure(avg_luminance, offset);
// #else
//     u_exposure_value;
// #endif
//     color = exposure * color;
    const float TONEMAPPING_SCALE = 1.0;
    return ACESFitted(color) * TONEMAPPING_SCALE;
}

#endif //_TONEMAPPING_