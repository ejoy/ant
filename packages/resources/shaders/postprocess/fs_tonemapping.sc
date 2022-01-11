$input v_texcoord0

#include <bgfx_shader.sh>
#include "tonemapping.sh"

SAMPLER2D(s_avg_luminance,  1);
SAMPLER2D(s_bloom_color,    2);


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
    gl_FragColor = vec4(tonemapping(color.rgb, avg_luminance, 0), color.a);
}