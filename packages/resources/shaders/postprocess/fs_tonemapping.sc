$input v_texcoord0

#include <bgfx_shader.sh>
#include "common/constants.sh"
#include "common/postprocess.sh"
#include "exposure.sh"
#include "aces.sh"

vec3 ToneMap(in vec3 color, in float avgLuminance, in float threshold, out float exposure)
{
    color = CalcExposedColor(color, avgLuminance, threshold, exposure);
    return ACESFitted(color) * 1.8f;
}

void main()
{
    float avgLuminance = 0.0; //GetAvgLuminance(InputTexture1);
    //vec3 color = InputTexture0.Sample(PointSampler, input.TexCoord).rgb;
    vec3 color = texture2D(s_postprocess_input0, v_texcoord0);

    //color += InputTexture2.Sample(LinearSampler, input.TexCoord).xyz * BloomMagnitude * exp2(BloomExposure);

    float exposure = 0;
    gl_FragColor = vec4(ToneMap(color, avgLuminance, 0, exposure), 1.0);
    // vec4 c           = texture2D(s_postprocess_input, v_texcoord0);
    // gl_FragColor.rgb = vec3_splat(1.0) - exp(-c.rgb * u_exposure);
    // gl_FragColor.a   = saturate(c.a);
}