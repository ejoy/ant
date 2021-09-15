$input v_texcoord0

#include <bgfx_shader.sh>
#include "tonemapping.sh"

void main()
{
    float avgLuminance = 0.0; //GetAvgLuminance(InputTexture1);
    //vec3 color = InputTexture0.Sample(PointSampler, input.TexCoord).rgb;
    vec4 color = texture2D(s_postprocess_input0, v_texcoord0);

    //color += InputTexture2.Sample(LinearSampler, input.TexCoord).xyz * BloomMagnitude * exp2(BloomExposure);

    gl_FragColor = vec4(ToneMap(color, avgLuminance, 0), color.a);
    // vec4 c           = texture2D(s_postprocess_input, v_texcoord0);
    // gl_FragColor.rgb = vec3_splat(1.0) - exp(-c.rgb * u_exposure);
    // gl_FragColor.a   = saturate(c.a);
}