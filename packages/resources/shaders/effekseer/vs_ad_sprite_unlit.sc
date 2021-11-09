$input a_position, a_color0, a_texcoord0, a_texcoord1, a_texcoord2, a_texcoord3
$output v_PosVS, v_VColor, v_UV_Others, v_WorldN, v_Alpha_Dist_UV, v_Blend_Alpha_Dist_UV, v_Blend_FBNextIndex_UV, v_PosP

#include <common.sh>

struct VS_Input
{
    vec3 Pos;
    vec4 Color;
    vec2 UV;
    vec4 Alpha_Dist_UV;
    vec2 BlendUV;
    vec4 Blend_Alpha_Dist_UV;
    float FlipbookIndex;
    float AlphaThreshold;
};

struct VS_Output
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

uniform mat4 u_camera;
uniform mat4 u_cameraProj;
uniform vec4 u_UVInversed;
uniform vec4 u_vsFlipbookParameter;

vec2 GetFlipbookOneSizeUV(float DivideX, float DivideY)
{
    return vec2_splat(1.0) / vec2(DivideX, DivideY);
}

vec2 GetFlipbookOriginUV(vec2 FlipbookUV, float FlipbookIndex, float DivideX, float DivideY)
{
    vec2 DivideIndex;
    DivideIndex.x = float(int(FlipbookIndex) % int(DivideX));
    DivideIndex.y = float(int(FlipbookIndex) / int(DivideX));
    float param = DivideX;
    float param_1 = DivideY;
    vec2 FlipbookOneSize = GetFlipbookOneSizeUV(param, param_1);
    vec2 UVOffset = DivideIndex * FlipbookOneSize;
    vec2 OriginUV = FlipbookUV - UVOffset;
    OriginUV *= vec2(DivideX, DivideY);
    return OriginUV;
}

vec2 GetFlipbookUVForIndex(vec2 OriginUV, float Index, float DivideX, float DivideY)
{
    vec2 DivideIndex;
    DivideIndex.x = float(int(Index) % int(DivideX));
    DivideIndex.y = float(int(Index) / int(DivideX));
    float param = DivideX;
    float param_1 = DivideY;
    vec2 FlipbookOneSize = GetFlipbookOneSizeUV(param, param_1);
    return (OriginUV * FlipbookOneSize) + (DivideIndex * FlipbookOneSize);
}

void ApplyFlipbookVS(inout float flipbookRate, inout vec2 flipbookUV, vec4 flipbookParameter, float flipbookIndex, vec2 uv, vec2 uvInversed)
{
    if (flipbookParameter.x > 0.0)
    {
        flipbookRate = fract(flipbookIndex);
        float Index = floor(flipbookIndex);
        float IndexOffset = 1.0;
        float NextIndex = Index + IndexOffset;
        float FlipbookMaxCount = flipbookParameter.z * flipbookParameter.w;
        if (flipbookParameter.y == 0.0)
        {
            if (NextIndex >= FlipbookMaxCount)
            {
                NextIndex = FlipbookMaxCount - 1.0;
                Index = FlipbookMaxCount - 1.0;
            }
        }
        else
        {
            if (flipbookParameter.y == 1.0)
            {
                Index = mod(Index, FlipbookMaxCount);
                NextIndex = mod(NextIndex, FlipbookMaxCount);
            }
            else
            {
                if (flipbookParameter.y == 2.0)
                {
                    bool Reverse = mod(floor(Index / FlipbookMaxCount), 2.0) == 1.0;
                    Index = mod(Index, FlipbookMaxCount);
                    if (Reverse)
                    {
                        Index = (FlipbookMaxCount - 1.0) - floor(Index);
                    }
                    Reverse = mod(floor(NextIndex / FlipbookMaxCount), 2.0) == 1.0;
                    NextIndex = mod(NextIndex, FlipbookMaxCount);
                    if (Reverse)
                    {
                        NextIndex = (FlipbookMaxCount - 1.0) - floor(NextIndex);
                    }
                }
            }
        }
        vec2 notInversedUV = uv;
        notInversedUV.y = uvInversed.x + (uvInversed.y * notInversedUV.y);
        vec2 param = notInversedUV;
        float param_1 = Index;
        float param_2 = flipbookParameter.z;
        float param_3 = flipbookParameter.w;
        vec2 OriginUV = GetFlipbookOriginUV(param, param_1, param_2, param_3);
        vec2 param_4 = OriginUV;
        float param_5 = NextIndex;
        float param_6 = flipbookParameter.z;
        float param_7 = flipbookParameter.w;
        flipbookUV = GetFlipbookUVForIndex(param_4, param_5, param_6, param_7);
        flipbookUV.y = uvInversed.x + (uvInversed.y * flipbookUV.y);
    }
}

void CalculateAndStoreAdvancedParameter(VS_Input vsinput, inout VS_Output vsoutput)
{
    vsoutput.Alpha_Dist_UV = vsinput.Alpha_Dist_UV;
    vsoutput.Alpha_Dist_UV.y = u_UVInversed.x + (u_UVInversed.y * vsinput.Alpha_Dist_UV.y);
    vsoutput.Alpha_Dist_UV.w = u_UVInversed.x + (u_UVInversed.y * vsinput.Alpha_Dist_UV.w);
    vsoutput.Blend_FBNextIndex_UV = vec4(vsinput.BlendUV.x, vsinput.BlendUV.y, vsoutput.Blend_FBNextIndex_UV.z, vsoutput.Blend_FBNextIndex_UV.w);
    vsoutput.Blend_FBNextIndex_UV.y = u_UVInversed.x + (u_UVInversed.y * vsinput.BlendUV.y);
    vsoutput.Blend_Alpha_Dist_UV = vsinput.Blend_Alpha_Dist_UV;
    vsoutput.Blend_Alpha_Dist_UV.y = u_UVInversed.x + (u_UVInversed.y * vsinput.Blend_Alpha_Dist_UV.y);
    vsoutput.Blend_Alpha_Dist_UV.w = u_UVInversed.x + (u_UVInversed.y * vsinput.Blend_Alpha_Dist_UV.w);
    float flipbookRate = 0.0;
    vec2 flipbookNextIndexUV = vec2_splat(0.0);
    float param = flipbookRate;
    vec2 param_1 = flipbookNextIndexUV;
    vec4 param_2 = u_vsFlipbookParameter;
    float param_3 = vsinput.FlipbookIndex;
    vec2 param_4 = vsoutput.UV_Others.xy;
    vec2 param_5 = vec2(u_UVInversed.xy);
    ApplyFlipbookVS(param, param_1, param_2, param_3, param_4, param_5);
    flipbookRate = param;
    flipbookNextIndexUV = param_1;
    vsoutput.Blend_FBNextIndex_UV = vec4(vsoutput.Blend_FBNextIndex_UV.x, vsoutput.Blend_FBNextIndex_UV.y, flipbookNextIndexUV.x, flipbookNextIndexUV.y);
    vsoutput.UV_Others.z = flipbookRate;
    vsoutput.UV_Others.w = vsinput.AlphaThreshold;
}

VS_Output _main(VS_Input Input)
{
    VS_Output Output;// = VS_Output(vec4_splat(0.0), vec4_splat(0.0), vec4_splat(0.0), vec3_splat(0.0), vec4_splat(0.0), vec4_splat(0.0), vec4_splat(0.0), vec4_splat(0.0));
    Output.PosVS = vec4_splat(0.0);
    Output.Color = vec4_splat(0.0);
    Output.UV_Others = vec4_splat(0.0);
    Output.WorldN = vec3_splat(0.0);
    Output.Alpha_Dist_UV = vec4_splat(0.0);
    Output.Blend_Alpha_Dist_UV = vec4_splat(0.0);
    Output.Blend_FBNextIndex_UV = vec4_splat(0.0);
    Output.PosP = vec4_splat(0.0);
	vec2 uv1 = Input.UV;
    uv1.y = u_UVInversed.x + (u_UVInversed.y * uv1.y);
    Output.UV_Others = vec4(uv1.x, uv1.y, Output.UV_Others.z, Output.UV_Others.w);
    Output.PosVS = mul(u_cameraProj, vec4(Input.Pos, 1.0));
    Output.Color = Input.Color;
    VS_Input param = Input;
    VS_Output param_1 = Output;
    CalculateAndStoreAdvancedParameter(param, param_1);
    Output = param_1;
    Output.PosP = Output.PosVS;
    return Output;
}

void main()
{
    VS_Input Input;
    Input.Pos = a_position;
    Input.Color = a_color0;
    Input.UV = a_texcoord0;
    Input.Alpha_Dist_UV = a_texcoord1;
    Input.BlendUV = a_texcoord2.xy;
    Input.Blend_Alpha_Dist_UV.xy = a_texcoord2.zw;
	Input.Blend_Alpha_Dist_UV.zw = a_texcoord3.xy;
    Input.FlipbookIndex = a_texcoord3.z;
    Input.AlphaThreshold = a_texcoord3.w;
    VS_Output flattenTemp = _main(Input);
    gl_Position = flattenTemp.PosVS;
    v_VColor = flattenTemp.Color;
    v_UV_Others = flattenTemp.UV_Others;
    v_WorldN = flattenTemp.WorldN;
    v_Alpha_Dist_UV = flattenTemp.Alpha_Dist_UV;
    v_Blend_Alpha_Dist_UV = flattenTemp.Blend_Alpha_Dist_UV;
    v_Blend_FBNextIndex_UV = flattenTemp.Blend_FBNextIndex_UV;
    v_PosP = flattenTemp.PosP;
}
