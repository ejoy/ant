//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

// The two functions below were based on code and explanations provided by Padraic Hennessy (@PadraicHennessy).
// See this for more info: https://placeholderart.wordpress.com/2014/11/21/implementing-a-physically-based-camera-manual-exposure/

#ifndef _EXPOSURE_SH_
#define _EXPOSURE_SH_
#include "common/contants.sh"
#include "common/camera.sh"

#define MANUAL_EXPOSURE 1
#define AUTO_EXPOSURE   2

#if (EXPOSURE_TYPE == AUTO_EXPOSURE)
#   define u_auto_exposure_key u_exposure_param.x
#else
#   define u_exposure_value   u_exposure_param.x
#endif //EXPOSURE_TYPE

// #define AUTO_EXPOSURE   1
// #define SBS_EXPOSURE    2
// #define SOS_EXPOSURE    3
// #define MANUAL_EXPOSURE 4

// #ifndef EXPOSURE_TYPE
// #   define EXPOSURE_TYPE    MANUAL_EXPOSURE
// #endif  //!EXPOSURE_TYPE

// #if (EXPOSURE_TYPE == AUTO_EXPOSURE)
// #   define u_auto_exposure_key u_exposure_param.x
// #elif ((EXPOSURE_TYPE == SBS_EXPOSURE) || (EXPOSURE_TYPE == SOS_EXPOSURE))
// #   define u_aperture_f_number u_exposure_param.x
// #   define u_shutter_speed     u_exposure_param.y
// #   define u_ISO               u_exposure_param.z
// #else
// #   define u_manual_exposure   u_exposure_param.x
// #endif //EXPOSURE_TYPE

// #if EXPOSURE_TYPE == SBS_EXPOSURE
// float SaturationBasedExposure()
// {
//     float maxLuminance = (7800.0f / 65.0f) * (u_aperture_f_number * u_aperture_f_number) / (u_ISO * u_shutter_speed);
//     return log2(1.0f / maxLuminance);
// }
// #endif //EXPOSURE_TYPE == SBS_EXPOSURE

// #if EXPOSURE_TYPE == SOS_EXPOSURE
// float StandardOutputBasedExposure(float middleGrey = 0.18f)
// {
//     float lAvg = (1000.0f / 65.0f) * (u_aperture_f_number * u_aperture_f_number) / (u_ISO * u_shutter_speed);
//     return log2(middleGrey / lAvg);
// }
// #endif //EXPOSURE_TYPE == SOS_EXPOSURE

// float Log2Exposure(in float avgLuminance)
// {
//     float exposure = 0.0f;
// #if (EXPOSURE_TYPE == AUTO_EXPOSURE)
//     avgLuminance = max(avgLuminance, 0.00001f);
//     float linearExposure = (u_auto_exposure_key / avgLuminance);
//     exposure = log2(max(linearExposure, 0.00001f));
// #elif (EXPOSURE_TYPE == SBS_EXPOSURE)
//     exposure = SaturationBasedExposure() - log2(FP16Scale);
// #elif (EXPOSURE_TYPE == SOS_EXPOSURE)
//     exposure = StandardOutputBasedExposure() - log2(FP16Scale);
// #elif (EXPOSURE_TYPE == MANUAL_EXPOSURE)
//     exposure = u_manual_exposure - log2(FP16Scale);
// #endif //EXPOSURE_TYPE

//     return exposure;
// }

// float LinearExposure(in float avgLuminance)
// {
//     return exp2(Log2Exposure(avgLuminance));
// }

// vec3 CalcExposedColor(in vec3 color, in float avgLuminance, in float offset, out float exposure)
// {
//     exposure = Log2Exposure(avgLuminance);
//     exposure += offset;
//     return exp2(exposure) * color;
// }

#if EXPOSURE_TYPE == AUTO_EXPOSURE 
float calc_auto_exposure(float avg_luminance, float offset)
{
    avg_luminance = max(avg_luminance, 0.00001f);
    float linear_exposure = (u_auto_exposure_key / avg_luminance);
    //we should do log2 after linear_exposure and do exp2 after log2, it cancel out log2 and exp2, just reture linear_exposure
    return max(linear_exposure, 0.00001f);
}
#endif //EXPOSURE_TYPE == AUTO_EXPOSURE

#endif //_EXPOSURE_SH_