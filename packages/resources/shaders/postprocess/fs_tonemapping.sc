$input v_texcoord0

#include <bgfx_shader.sh>
#include "tonemapping.sh"

void main()
{
    float avgLuminance = 0.0;
#if EXPOSURE_TYPE == AUTO_EXPOSURE
    avgLuminance = textureFetch(s_postprocess_input1, ivec2(0, 0));   //s_postprocess_input1 is 1x1 texture
#endif //EXPOSURE_TYPE == AUTO_EXPOSURE

    vec4 color = texture2D(s_postprocess_input0, v_texcoord0);

    //color += InputTexture2.Sample(LinearSampler, input.TexCoord).xyz * BloomMagnitude * exp2(BloomExposure);

    gl_FragColor = vec4(ToneMap(color, avgLuminance, 0), color.a);
    // vec4 c           = texture2D(s_postprocess_input, v_texcoord0);
    // gl_FragColor.rgb = vec3_splat(1.0) - exp(-c.rgb * u_exposure);
    // gl_FragColor.a   = saturate(c.a);
}