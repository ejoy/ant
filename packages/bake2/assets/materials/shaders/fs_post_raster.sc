#include <bgfx_shader.sh>

SAMPLER2DMS(0, Positions);
SAMPLER2DMS(1, Normals);
SAMPLER2DMS(2, Tangents);
SAMPLER2DMS(3, Bitangents);
SAMPLER2DMS(4, Coverage);

void main()
{
    uvec2 uv = uvec2(gl_FragCoord.xy);

	static const uint NumSamples = 8;
    float numUsed = 0.0f;

    for(uint i = 0; i < NumSamples; ++i)
    {
        bgfxTexelFetch()
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