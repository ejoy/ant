//=================================================================================================
//
//  Baking Lab
//  by MJP and David Neubelt
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Constant buffers
//=================================================================================================
cbuffer Constants : register(b0)
{
    uint VertexOffset;
}

//=================================================================================================
// Input/Output structs
//=================================================================================================
struct VSInput
{
    float3 Position 		    : POSITION;
    float3 Normal 		        : NORMAL;
    float2 TexCoord 		    : TEXCOORD0;
    float2 LightMapUV           : TEXCOORD1;
	float3 Tangent 		        : TANGENT;
	float3 Bitangent		    : BITANGENT;
};

struct VSOutput
{
    float4 PositionCS 		    : SV_Position;
	float3 PositionWS 		    : POSITIONWS;
    float3 Normal 		        : NORMAL;
	float3 Tangent 		        : TANGENT;
	float3 Bitangent		    : BITANGENT;
};

struct PSInput
{
    sample float4 PositionCS 		        : SV_Position;
	sample float3 PositionWS 		        : POSITIONWS;
    sample float3 Normal 		            : NORMAL;
	sample float3 Tangent 		            : TANGENT;
	sample float3 Bitangent		            : BITANGENT;
};

struct PSOutput
{
    float4 Position_SizeX 		: SV_Target0;
    float4 Normal_SizeY 		: SV_Target1;
	float3 Tangent 		        : SV_Target2;
	float3 Bitangent		    : SV_Target3;
    uint Coverage               : SV_Target4;
};

//=================================================================================================
// Vertex Shader
//=================================================================================================
VSOutput VS(in VSInput input)
{
    VSOutput output;

    // Calc the clip-space position based on the lightmap texture coordinates
    output.PositionCS = float4((input.LightMapUV * 2.0f - 1.0f) * float2(1.0f, -1.0f), 1.0f, 1.0f);

	// Pass along the vertex data
	output.PositionWS = input.Position;
    output.Normal = input.Normal;
    output.Tangent = input.Tangent;
    output.Bitangent = input.Bitangent;

    return output;
}

//=================================================================================================
// Pixel Shader
//=================================================================================================
PSOutput PS(in PSInput input)
{
    float width = length(ddx(input.PositionWS));
    float height = length(ddx(input.PositionWS));

	// Output the vertex data + coverage
    PSOutput output;
    output.Position_SizeX = float4(input.PositionWS, width);
    output.Normal_SizeY = float4(normalize(input.Normal), height);
    output.Tangent = normalize(input.Tangent);
    output.Bitangent = normalize(input.Bitangent);
    output.Coverage = 1;

    return output;
}

//=================================================================================================
// Vertex shader for rendering a full-screen triangle
//=================================================================================================
float4 ResolveVS(in uint VertexID : SV_VertexID) : SV_Position
{
    float4 position;

    if(VertexID == 0)
        position = float4(-1.0f, 1.0f, 1.0f, 1.0f);
    else if(VertexID == 1)
        position = float4(3.0f, 1.0f, 1.0f, 1.0f);
    else
        position = float4(-1.0f, -3.0f, 1.0f, 1.0f);

    return position;
}

Texture2DMS<float4> Positions : register(t0);
Texture2DMS<float4> Normals : register(t1);
Texture2DMS<float3> Tangents : register(t2);
Texture2DMS<float3> Bitangents : register(t3);
Texture2DMS<uint> Coverage : register(t4);

//=================================================================================================
// Pixel Shader for resolving the MSAA rasterization target
//=================================================================================================
PSOutput ResolvePS(in float4 Position : SV_Position)
{
    PSOutput output;
    output.Position_SizeX = 0.0f;
    output.Normal_SizeY = 0.0f;
    output.Tangent = 0.0f;
    output.Bitangent = 0.0f;
    output.Coverage = 0;

	static const uint NumSamples = 8;
    float numUsed = 0.0f;

    [unroll]
    for(uint i = 0; i < NumSamples; ++i)
    {
        uint coverage = Coverage.Load(uint2(Position.xy), i);
        if(coverage != 0)
        {
            output.Position_SizeX += Positions.Load(uint2(Position.xy), i);
            output.Normal_SizeY += Normals.Load(uint2(Position.xy), i);
            output.Tangent += Tangents.Load(uint2(Position.xy), i);
            output.Bitangent += Bitangents.Load(uint2(Position.xy), i);

            numUsed += 1.0f;
            output.Coverage |= (1 << i);
        }
    }

    if(numUsed > 0.0f)
    {
        output.Position_SizeX /= numUsed;
        output.Normal_SizeY = output.Normal_SizeY / numUsed;
        output.Normal_SizeY.xyz = normalize(output.Normal_SizeY.xyz);
        output.Tangent = normalize(output.Tangent / numUsed);
        output.Bitangent = normalize(output.Bitangent / numUsed);
    }

    return output;
}