$input v_PosP, v_UV1, v_VColor

#include <common.sh>

SAMPLER2D(s_sampler_colorTex, 0);
SAMPLER2D(s_sampler_depthTex, 1);

uniform vec4 fLightDirection;
uniform vec4 fLightColor;
uniform vec4 fLightAmbient;
uniform vec4 fFlipbookParameter;
uniform vec4 fUVDistortionParameter;
uniform vec4 fBlendTextureParameter;
uniform vec4 fCameraFrontDirection;
uniform vec4 fFalloffParameter;
uniform vec4 fFalloffBeginColor;
uniform vec4 fFalloffEndColor;
uniform vec4 fEmissiveScaling;
uniform vec4 fEdgeColor;
uniform vec4 fEdgeParameter;
uniform vec4 softParticleParam;
uniform vec4 reconstructionParam1;
uniform vec4 reconstructionParam2;

float SoftParticle(float backgroundZ, float meshZ, vec4 softparticleParam, vec4 reconstruct1, vec4 reconstruct2)
{
    float distanceFar = softparticleParam.x;
    float distanceNear = softparticleParam.y;
    float distanceNearOffset = softparticleParam.z;
    vec2 rescale = reconstruct1.xy;
    vec4 params = reconstruct2;
    vec2 zs = vec2((backgroundZ * rescale.x) + rescale.y, meshZ);
    vec2 depth = ((zs * params.w) - vec2_splat(params.y)) / (vec2_splat(params.x) - (zs * params.z));
    float alphaFar = (depth.y - depth.x) / distanceFar;
    float alphaNear = ((-distanceNearOffset) - depth.y) / distanceNear;
    return min(max(min(alphaFar, alphaNear), 0.0), 1.0);
}

void main()
{
	vec4 Output = texture2D(s_sampler_colorTex, v_UV1) * v_VColor;
    vec4 screenPos = v_PosP / v_PosP.w;
    vec2 screenUV = (screenPos.xy + vec2_splat(1.0)) / vec2_splat(2.0);
    screenUV.y = 1.0 - screenUV.y;
    screenUV.y = 1.0 - screenUV.y;
    if (!(softParticleParam.w == 0.0))
    {
        float backgroundZ = texture2D(s_sampler_depthTex, screenUV).x;
        float param = backgroundZ;
        float param_1 = screenPos.z;
        vec4 param_2 = softParticleParam;
        vec4 param_3 = reconstructionParam1;
        vec4 param_4 = reconstructionParam2;
        Output.w *= SoftParticle(param, param_1, param_2, param_3, param_4);
    }
    if (Output.w == 0.0)
    {
        discard;
    }
	gl_FragColor = Output;
}
