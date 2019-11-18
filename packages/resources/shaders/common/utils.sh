#ifndef __SHADER_UTILS_SH__
#define __SHADER_UTILS_SH__
#include <shaderlib.sh>

vec4 texture2D_sRGB(sampler2D tex, vec2 coord)
{
    vec4 color = texture2D(tex, coord);
#ifdef ENABLE_SRGB_TEXTURE
    return color;
#else   //!ENABLE_SRGB_TEXTURE
    return vec4(toLinear(color.rgb), color.a);
#endif  //ENABLE_SRGB_TEXTURE
}

vec4 output_color_sRGB(vec4 outcolor)
{
#ifdef  ENABLE_FB_SRGB
    return outcolor;
#else   //!ENABLE_FB_SRGB
    return vec4(toGamma(outcolor.rgb), outcolor.a);
#endif  //ENABLE_FB_SRGB
}

#endif //__SHADER_UTILS_SH__