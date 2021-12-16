$input v_texcoord0

#include <bgfx_shader.sh>
#include "tonemapping.sh"

#define s_avg_luminance s_postprocess_input1

void main()
{
    float avg_luminance = 0.0;
#if EXPOSURE_TYPE == AUTO_EXPOSURE
    avg_luminance = texelFetch(s_avg_luminance, ivec2(0, 0), 0);   //s_avg_luminance is 1x1 texture
#endif //EXPOSURE_TYPE == AUTO_EXPOSURE

    vec4 color = texture2D(s_postprocess_input0, v_texcoord0);
    gl_FragColor = vec4(tonemapping(color.rgb, avg_luminance, 0), color.a);
}