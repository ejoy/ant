#ifndef _TONEMAPPING_
#define _TONEMAPPING_

#include "common/constants.sh"
#include "common/postprocess.sh"
#include "exposure.sh"
#include "aces.sh"

vec3 ToneMap(in vec3 color, float avgLuminance, float threshold)
{
    float exposure = 0.0;
    color = CalcExposedColor(color, avgLuminance, threshold, exposure);
    return ACESFitted(color) * 1.8;
}

#endif //_TONEMAPPING_