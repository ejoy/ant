#ifndef _TONEMAPPING_
#define _TONEMAPPING_

#include "common/constants.sh"
#include "common/postprocess.sh"
#include "exposure.sh"
#include "aces.sh"

vec3 tonemapping(in vec3 color, float avg_luminance, float offset)
{
    float exposure = 
#if EXPOSURE_TYPE == AUTO_EXPOSURE 
    calc_auto_exposure(avg_luminance, offset);
#else
    u_exposure_value;
#endif
    color = exposure * color;
    return ACESFitted(color) * 1.8;
}

#endif //_TONEMAPPING_