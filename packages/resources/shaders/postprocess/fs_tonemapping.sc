$input v_texcoord0

#include <bgfx_shader.sh>
#include "tonemapping.sh"

SAMPLER2D(s_avg_luminance,  1);
SAMPLER2D(s_bloom_color,    2);

#ifdef COMPUTE_LUMINANCE_TO_ALPHA
float toluma(vec3 rbg)
{
    return dot(vec3(0.2126729, 0.7151522, 0.0721750), rbg);
}
#endif //COMPUTE_LUMINANCE_TO_ALPHA

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

    const vec3 clr = tonemapping(color.rgb, avg_luminance, 0);
#ifdef COMPUTE_LUMINANCE_TO_ALPHA
    // fxaa need color in sRGB space, luma in linear space, use sqrt for inverse gamma operation and assume gamma is 2.0
    gl_FragColor = vec4(clr, sqrt(toluma(clr)));
#else //!COMPUTE_LUMINANCE_TO_ALPHA
    gl_FragColor = vec4(clr, color.a);
#endif //COMPUTE_LUMINANCE_TO_ALPHA
}