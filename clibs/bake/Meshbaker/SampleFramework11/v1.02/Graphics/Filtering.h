//=================================================================================================
//
//  MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

#include "..\\PCH.h"
#include "..\\SF11_Math.h"

namespace SampleFramework11
{

inline float FilterBox1D(float x)
{
    x = std::abs(x);
    return x <= 1.0f ? 1.0f : 0.0f;
}

inline float FilterBox2D(Float2 xy)
{
    return FilterBox1D(xy.x) * FilterBox1D(xy.y);
}

inline float FilterCircle2D(Float2 xy)
{
    return FilterBox1D(Float2::Length(xy));
}

inline float FilterTriangle1D(float x)
{
    x = std::abs(x);
    return Saturate(1.0f - std::abs(x));
}

inline float FilterTriangle2D(Float2 xy)
{
    return FilterTriangle1D(xy.x) * FilterTriangle1D(xy.y);
}

inline float FilterCone2D(Float2 xy)
{
    return FilterTriangle1D(Float2::Length(xy));
}

inline float FilterGaussian1D(float x, float sigma)
{
    x = std::abs(x);
    const float g = 1.0f / std::sqrt(2.0f * 3.14159f * sigma * sigma);
    return (g * std::exp(-(x * x) / (2 * sigma * sigma)));
}

inline float FilterGaussian2D(Float2 xy, float sigma)
{
    return FilterGaussian1D(xy.x, sigma) * FilterGaussian1D(xy.y, sigma);
}

inline float FilterCubic1D(float x, float B, float C)
{
    // Rescale from [-1, 1] range to [-2, 2]
    x = std::abs(x) * 2.0f;

    float y = 0.0f;
    float x2 = x * x;
    float x3 = x * x * x;
    if(x < 1)
        y = (12 - 9 * B - 6 * C) * x3 + (-18 + 12 * B + 6 * C) * x2 + (6 - 2 * B);
    else if(x <= 2)
        y = (-B - 6 * C) * x3 + (6 * B + 30 * C) * x2 + (-12 * B - 48 * C) * x + (8 * B + 24 * C);

    return y / 6.0f;
}

inline float FilterCubic2D(Float2 xy, float B, float C)
{
    return FilterCubic1D(xy.x, B, C) * FilterCubic1D(xy.y, B, C);
}

inline float FilterBSpline1D(float x)
{
    return FilterCubic1D(x, 1.0f, 0.0f);
}

inline float FilterBSpline2D(Float2 xy)
{
    return FilterBSpline1D(xy.x) * FilterBSpline1D(xy.y);
}

inline float FilterCatmullRom1D(float x)
{
    return FilterCubic1D(x, 0.0f, 0.5f);
}

inline float FilterCatmullRom2D(Float2 xy)
{
    return FilterCatmullRom1D(xy.x) * FilterCatmullRom1D(xy.y);
}

inline float FilterMitchell1D(float x)
{
    return FilterCubic1D(x, 1 / 3.0f, 1 / 3.0f);
}

inline float FilterMitchell2D(Float2 xy)
{
    return FilterMitchell1D(xy.x) * FilterMitchell1D(xy.y);
}

inline float FilterSinc1D(float x)
{
    x = std::abs(x);

    float s;
    if(x < 0.001f)
        s = 1.0f;
    else
        s = std::sin(x * Pi) / (x * Pi);

    return s;
}

inline float BlackmanHarris(float x)
{
    const float a0 = 0.35875f;
    const float a1 = 0.48829f;
    const float a2 = 0.14128f;
    const float a3 = 0.01168f;
    return a0 - a1 * std::cos(Pi * x) + a2 * std::cos(2 * Pi * x) - a3 * std::cos(3 * Pi * x);
}

inline float FilterBlackmanHarris1D(float x)
{
    float t = 1.0f - std::abs(x);
    return Saturate(BlackmanHarris(t));
}

inline float FilterSmoothstep1D(float x)
{
    x = std::abs(x);
    return 1.0f - Smoothstep(0.0f, 1.0f, x);
}

inline float FilterSmoothstep2D(Float2 xy)
{
    return FilterSmoothstep1D(Float2::Length(xy));
}

}