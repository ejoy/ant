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

float SaturationBasedExposure()
{
    float maxLuminance = (7800.0f / 65.0f) * (ApertureFNumber * ApertureFNumber) / (ISO * ShutterSpeedValue);
    return log2(1.0f / maxLuminance);
}

float StandardOutputBasedExposure(float middleGrey = 0.18f)
{
    float lAvg = (1000.0f / 65.0f) * (ApertureFNumber * ApertureFNumber) / (ISO * ShutterSpeedValue);
    return log2(middleGrey / lAvg);
}

float Log2Exposure(in float avgLuminance)
{
    float exposure = 0.0f;

    if(ExposureMode == ExposureModes_Automatic)
    {
        avgLuminance = max(avgLuminance, 0.00001f);
        float linearExposure = (KeyValue / avgLuminance);
        exposure = log2(max(linearExposure, 0.00001f));
    }
    else if(ExposureMode == ExposureModes_Manual_SBS)
    {
        exposure = SaturationBasedExposure();
        exposure -= log2(FP16Scale);
    }
    else if(ExposureMode == ExposureModes_Manual_SOS)
    {
        exposure = StandardOutputBasedExposure();
        exposure -= log2(FP16Scale);
    }
    else
    {
        exposure = ManualExposure;
        exposure -= log2(FP16Scale);
    }

    return exposure;
}

float LinearExposure(in float avgLuminance)
{
    return exp2(Log2Exposure(avgLuminance));
}

// Determines the color based on exposure settings
float3 CalcExposedColor(in float3 color, in float avgLuminance, in float offset, out float exposure)
{
    exposure = Log2Exposure(avgLuminance);
    exposure += offset;
    return exp2(exposure) * color;
}