//=================================================================================================
//
//	MJP's DX11 Sample Framework
//  http://mynameismjp.wordpress.com/
//
//  All code licensed under the MIT license
//
//=================================================================================================

//=================================================================================================
// Float/half conversion functions
//=================================================================================================
uint2 Float4ToHalf(in float4 val)
{
	uint2 result = 0;
	result.x = f32tof16(val.x);
	result.x |= f32tof16(val.y) << 16;
	result.y = f32tof16(val.z);
	result.y |= f32tof16(val.w) << 16;

	return result;
}

uint2 Float3ToHalf(in float3 val)
{
	uint2 result = 0;
	result.x = f32tof16(val.x);
	result.x |= f32tof16(val.y) << 16;
	result.y = f32tof16(val.z);

	return result;
}

uint Float2ToHalf(in float2 val)
{
	uint result = 0;
	result = f32tof16(val.x);
	result |= f32tof16(val.y) << 16;

	return result;
}

float4 HalfToFloat4(in uint2 val)
{
	float4 result;
	result.x = f16tof32(val.x);
	result.y = f16tof32(val.x >> 16);
	result.z = f16tof32(val.y);
	result.w = f16tof32(val.y >> 16);

	return result;
}

float3 HalfToFloat3(in uint2 val)
{
	float3 result;
	result.x = f16tof32(val.x);
	result.y = f16tof32(val.x >> 16);
	result.z = f16tof32(val.y);

	return result;
}

float2 HalfToFloat2(in uint val)
{
	float2 result;
	result.x = f16tof32(val);
	result.y = f16tof32(val >> 16);

	return result;
}