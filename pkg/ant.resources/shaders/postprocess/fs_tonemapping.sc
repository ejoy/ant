$input v_texcoord0

#include <bgfx_shader.sh>
#include <shaderlib.sh>
#include "tonemapping.sh"

SAMPLER2D(s_avg_luminance,  1);
SAMPLER2D(s_bloom_color,    2);

#ifdef ENABLE_TONEMAP_LUT
SAMPLER3D(s_colorgrading_lut, 3);
#endif //ENABLE_TONEMAP_LUT

#ifdef COMPUTE_LUMINANCE_TO_ALPHA
float toluma(vec3 rbg)
{
    return dot(vec3(0.2126729, 0.7151522, 0.0721750), rbg);
}
#endif //COMPUTE_LUMINANCE_TO_ALPHA

#ifdef ENABLE_TONEMAP_LUT
vec3 log10(vec3 v){ return log2(v) / log2(10.0);}
vec3 linear2LogC(vec3 x)
{
    // Alexa LogC EI 1000
    const float a = 5.555556;
    const float b = 0.047996;
    const float c = 0.244161;
    const float d = 0.386036;
    return c * log10(a * x + b) + d;
}
#endif //ENABLE_TONEMAP_LUT


vec3 do_tonemap(vec3 color, float avg_luminance)
{
#ifdef ENABLE_TONEMAP_LUT
    vec3 logc = linear2LogC(color);
    const int3 size = textureSize(s_colorgrading_lut, 0);

    //make logc align to pixel center
    float texelsize = 1.0 / size.x;
    logc = vec3_splat(0.5 * texelsize) + logc * (1.0 - texelsize);
    logc = max(vec3_splat(0.0), logc);
    #ifdef ENABLE_RGBE_FORMAT
        vec4 rgbe = texture3DLod(s_colorgrading_lut, logc, 0.0);
        return decodeRGBE8(rgbe);
    #else//!ENABLE_RGBE_FORMAT
        return texture3DLod(s_colorgrading_lut, logc, 0.0).rgb;
    #endif//ENABLE_RGBE_FORMAT
#else //!ENABLE_TONEMAP_LUT
    return tonemapping(color.rgb, avg_luminance, 0);
#endif //ENABLE_TONEMAP_LUT
}

void main()
{
    float avg_luminance = 0.0;
#if EXPOSURE_TYPE == AUTO_EXPOSURE
    avg_luminance = texelFetch(s_avg_luminance, ivec2(0, 0), 0);   //s_avg_luminance is 1x1 texture
#endif //EXPOSURE_TYPE == AUTO_EXPOSURE

    vec4 color = texture2D(s_scene_color, v_texcoord0);
#ifdef BLOOM_ENABLE
    vec3 bloomcolor = texture2D(s_bloom_color, v_texcoord0).rgb;
    color.rgb += bloomcolor;
#endif //BLOOM_ENABLE

    const vec3 clr = do_tonemap(color.rgb, avg_luminance);

#ifdef COMPUTE_LUMINANCE_TO_ALPHA
    // fxaa need color in sRGB space, luma in linear space, use sqrt for inverse gamma operation and assume gamma is 2.0
    gl_FragColor = vec4(clr, sqrt(toluma(clr)));
#else //!COMPUTE_LUMINANCE_TO_ALPHA
    gl_FragColor = vec4(clr, color.a);
#endif //COMPUTE_LUMINANCE_TO_ALPHA
}