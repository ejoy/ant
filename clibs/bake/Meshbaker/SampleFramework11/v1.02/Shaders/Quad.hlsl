//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Input/Output structs
//=================================================================================================

struct VSInput
{
    float4 PositionCS : POSITION;
    float2 TexCoord : TEXCOORD;
};

struct VSOutput
{
    float4 PositionCS : SV_Position;
    float2 TexCoord : TEXCOORD;
};

//=================================================================================================
// Vertex Shader
//=================================================================================================
VSOutput QuadVS(in VSInput input)
{
    VSOutput output;

    // Just pass it along
    output.PositionCS = input.PositionCS;
    output.TexCoord = input.TexCoord;

    return output;
}