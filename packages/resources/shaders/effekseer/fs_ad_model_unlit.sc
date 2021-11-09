$input v_PosVS, v_VColor, v_UV_Others, v_WorldN, v_Alpha_Dist_UV, v_Blend_Alpha_Dist_UV, v_Blend_FBNextIndex_UV, v_PosP

#include <common.sh>

struct PS_Input
{
    vec4 PosVS;
    vec4 Color;
    vec4 UV_Others;
    vec3 WorldN;
    vec4 Alpha_Dist_UV;
    vec4 Blend_Alpha_Dist_UV;
    vec4 Blend_FBNextIndex_UV;
    vec4 PosP;
};

struct AdvancedParameter
{
    vec2 AlphaUV;
    vec2 UVDistortionUV;
    vec2 BlendUV;
    vec2 BlendAlphaUV;
    vec2 BlendUVDistortionUV;
    vec2 FlipbookNextIndexUV;
    float FlipbookRate;
    float AlphaThreshold;
};

//uniform vec4 fLightDirection;
//uniform vec4 fLightColor;
//uniform vec4 fLightAmbient;
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
uniform vec4 mUVInversedBack;

SAMPLER2D(s_sampler_colorTex, 0);
SAMPLER2D(s_sampler_alphaTex, 1);
SAMPLER2D(s_sampler_uvDistortionTex, 2);
SAMPLER2D(s_sampler_blendTex, 3);
SAMPLER2D(s_sampler_blendAlphaTex, 4);
SAMPLER2D(s_sampler_blendUVDistortionTex, 5);
SAMPLER2D(s_sampler_depthTex, 6);

AdvancedParameter DisolveAdvancedParameter(PS_Input psinput)
{
    AdvancedParameter ret;
    ret.AlphaUV = psinput.Alpha_Dist_UV.xy;
    ret.UVDistortionUV = psinput.Alpha_Dist_UV.zw;
    ret.BlendUV = psinput.Blend_FBNextIndex_UV.xy;
    ret.BlendAlphaUV = psinput.Blend_Alpha_Dist_UV.xy;
    ret.BlendUVDistortionUV = psinput.Blend_Alpha_Dist_UV.zw;
    ret.FlipbookNextIndexUV = psinput.Blend_FBNextIndex_UV.zw;
    ret.FlipbookRate = psinput.UV_Others.z;
    ret.AlphaThreshold = psinput.UV_Others.w;
    return ret;
}

vec2 UVDistortionOffset(vec2 uv, vec2 uvInversed, sampler2D SPIRV_Cross_Combinedts)
{
    vec2 UVOffset = (texture2D(SPIRV_Cross_Combinedts, uv).xy * 2.0) - vec2_splat(1.0);
    UVOffset.y *= (-1.0);
    UVOffset.y = uvInversed.x + (uvInversed.y * UVOffset.y);
    return UVOffset;
}

void ApplyFlipbook(inout vec4 dst, vec4 flipbookParameter, vec4 vcolor, vec2 nextUV, float flipbookRate, sampler2D SPIRV_Cross_Combinedts)
{
    if (flipbookParameter.x > 0.0)
    {
        vec4 NextPixelColor = texture2D(SPIRV_Cross_Combinedts, nextUV) * vcolor;
        if (flipbookParameter.y == 1.0)
        {
            dst = mix(dst, NextPixelColor, vec4_splat(flipbookRate));
        }
    }
}

void ApplyTextureBlending(inout vec4 dstColor, vec4 blendColor, float blendType)
{
    if (blendType == 0.0)
    {
        vec3 _93 = (blendColor.xyz * blendColor.w) + (dstColor.xyz * (1.0 - blendColor.w));
        dstColor = vec4(_93.x, _93.y, _93.z, dstColor.w);
    }
    else
    {
        if (blendType == 1.0)
        {
            vec3 _105 = dstColor.xyz + (blendColor.xyz * blendColor.w);
            dstColor = vec4(_105.x, _105.y, _105.z, dstColor.w);
        }
        else
        {
            if (blendType == 2.0)
            {
                vec3 _118 = dstColor.xyz - (blendColor.xyz * blendColor.w);
                dstColor = vec4(_118.x, _118.y, _118.z, dstColor.w);
            }
            else
            {
                if (blendType == 3.0)
                {
                    vec3 _131 = dstColor.xyz * (blendColor.xyz * blendColor.w);
                    dstColor = vec4(_131.x, _131.y, _131.z, dstColor.w);
                }
            }
        }
    }
}

float SoftParticle(float backgroundZ, float meshZ, vec4 softparticleParam, vec4 reconstruct1, vec4 reconstruct2)
{
    float distanceFar = softparticleParam.x;
    float distanceNear = softparticleParam.y;
    float distanceNearOffset = softparticleParam.z;
    vec2 rescale = reconstruct1.xy;
    vec4 params = reconstruct2;
    vec2 zs = vec2((backgroundZ * rescale.x) + rescale.y, meshZ);
    vec2 depth = ((zs * params.w) - vec2_splat(params.y)) / (vec2_splat(params.x) - (zs * params.z));
    float dir = sign(depth.x);
    depth *= dir;
    float alphaFar = (depth.x - depth.y) / distanceFar;
    float alphaNear = (depth.y - distanceNearOffset) / distanceNear;
    return min(max(min(alphaFar, alphaNear), 0.0), 1.0);
}

vec4 _main(PS_Input Input)
{
    PS_Input param = Input;
    AdvancedParameter advancedParam = DisolveAdvancedParameter(param);
    vec2 param_1 = advancedParam.UVDistortionUV;
    vec2 param_2 = fUVDistortionParameter.zw;
    vec2 UVOffset = UVDistortionOffset(param_1, param_2, s_sampler_uvDistortionTex);
    UVOffset *= fUVDistortionParameter.x;
    vec4 Output = texture2D(s_sampler_colorTex, Input.UV_Others.xy + UVOffset) * Input.Color;
    vec4 param_3 = Output;
    float param_4 = advancedParam.FlipbookRate;
    ApplyFlipbook(param_3, fFlipbookParameter, Input.Color, advancedParam.FlipbookNextIndexUV + UVOffset, param_4, s_sampler_colorTex);
    Output = param_3;
    vec4 AlphaTexColor = texture2D(s_sampler_alphaTex, advancedParam.AlphaUV + UVOffset);
    Output.w *= (AlphaTexColor.x * AlphaTexColor.w);
    vec2 param_5 = advancedParam.BlendUVDistortionUV;
    vec2 param_6 = fUVDistortionParameter.zw;
    vec2 BlendUVOffset = UVDistortionOffset(param_5, param_6, s_sampler_blendUVDistortionTex);
    BlendUVOffset *= fUVDistortionParameter.y;
    vec4 BlendTextureColor = texture2D(s_sampler_blendTex, advancedParam.BlendUV + BlendUVOffset);
    vec4 BlendAlphaTextureColor = texture2D(s_sampler_blendAlphaTex, advancedParam.BlendAlphaUV + BlendUVOffset);
    BlendTextureColor.w *= (BlendAlphaTextureColor.x * BlendAlphaTextureColor.w);
    vec4 param_7 = Output;
    ApplyTextureBlending(param_7, BlendTextureColor, fBlendTextureParameter.x);
    Output = param_7;
    if (fFalloffParameter.x == 1.0)
    {
        vec3 cameraVec = normalize(-fCameraFrontDirection.xyz);
        float CdotN = clamp(dot(cameraVec, normalize(Input.WorldN)), 0.0, 1.0);
        vec4 FalloffBlendColor = mix(fFalloffEndColor, fFalloffBeginColor, vec4_splat(pow(CdotN, fFalloffParameter.z)));
        if (fFalloffParameter.y == 0.0)
        {
            vec3 _446 = Output.xyz + FalloffBlendColor.xyz;
            Output = vec4(_446.x, _446.y, _446.z, Output.w);
        }
        else
        {
            if (fFalloffParameter.y == 1.0)
            {
                vec3 _459 = Output.xyz - FalloffBlendColor.xyz;
                Output = vec4(_459.x, _459.y, _459.z, Output.w);
            }
            else
            {
                if (fFalloffParameter.y == 2.0)
                {
                    vec3 _472 = Output.xyz * FalloffBlendColor.xyz;
                    Output = vec4(_472.x, _472.y, _472.z, Output.w);
                }
            }
        }
        Output.w *= FalloffBlendColor.w;
    }
    vec3 _486 = Output.xyz * fEmissiveScaling.x;
    Output = vec4(_486.x, _486.y, _486.z, Output.w);
    vec4 screenPos = Input.PosP / vec4_splat(Input.PosP.w);
    vec2 screenUV = (screenPos.xy + vec2_splat(1.0)) / vec2_splat(2.0);
    screenUV.y = 1.0 - screenUV.y;
    screenUV.y = 1.0 - screenUV.y;
    screenUV.y = mUVInversedBack.x + (mUVInversedBack.y * screenUV.y);
    if (!(softParticleParam.w == 0.0))
    {
        float backgroundZ = texture2D(s_sampler_depthTex, screenUV).x;
        float param_8 = backgroundZ;
        float param_9 = screenPos.z;
        vec4 param_10 = softParticleParam;
        vec4 param_11 = reconstructionParam1;
        vec4 param_12 = reconstructionParam2;
        Output.w *= SoftParticle(param_8, param_9, param_10, param_11, param_12);
    }
    if (Output.w <= max(0.0, advancedParam.AlphaThreshold))
    {
        discard;
    }
    vec3 _584 = mix(fEdgeColor.xyz * fEdgeParameter.y, Output.xyz, vec3_splat(ceil((Output.w - advancedParam.AlphaThreshold) - fEdgeParameter.x)));
    Output = vec4(_584.x, _584.y, _584.z, Output.w);
    return Output;
}

void main()
{
    PS_Input Input;
    Input.PosVS = gl_FragCoord;
    Input.Color = v_VColor;
    Input.UV_Others = v_UV_Others;
    Input.WorldN = v_WorldN;
    Input.Alpha_Dist_UV = v_Alpha_Dist_UV;
    Input.Blend_Alpha_Dist_UV = v_Blend_Alpha_Dist_UV;
    Input.Blend_FBNextIndex_UV = v_Blend_FBNextIndex_UV;
    Input.PosP = v_PosP;
    gl_FragColor = _main(Input);
}