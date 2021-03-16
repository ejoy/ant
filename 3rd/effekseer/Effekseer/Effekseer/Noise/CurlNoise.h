#ifndef __EFFEKSEER_CURL_NOISE_H__
#define __EFFEKSEER_CURL_NOISE_H__

#include "../SIMD/Float4.h"
#include "../SIMD/Int4.h"
#include "../SIMD/Vec3f.h"
#include "PerlinNoise.h"

namespace Effekseer
{

class CurlNoise
{
private:
	PerlinNoise xnoise_;
	PerlinNoise ynoise_;
	PerlinNoise znoise_;

public:
	const float Scale = 1.0f;
	const int32_t Octave = 2;

	CurlNoise(int32_t seed, float scale, int32_t octave)
		: xnoise_(seed)
		, ynoise_(seed * (seed % 1949 + 5))
		, znoise_(seed * (seed % 3541 + 10))
		, Scale(scale)
		, Octave(octave)
	{
	}

	SIMD::Vec3f Get(SIMD::Vec3f pos) const;
};

class LightCurlNoise
{
private:
	static const int32_t GridSize = 8;
	uint32_t seed_ = 0;
	std::array<uint8_t, GridSize * GridSize * GridSize> vectorField_x_;
	std::array<uint8_t, GridSize * GridSize * GridSize> vectorField_y_;
	std::array<uint8_t, GridSize * GridSize * GridSize> vectorField_z_;

	float GetRand()
	{
		const int a = 1103515245;
		const int c = 12345;
		const int m = 2147483647;

		seed_ = (seed_ * a + c) & m;
		auto ret = seed_ % 0x7fff;

		return (float)ret / (float)(0x7fff - 1);
	}

	float GetRand(float min_, float max_)
	{
		return GetRand() * (max_ - min_) + min_;
	}

	uint8_t Pack(const float v) const;

	float Unpack(const uint8_t v) const;

public:
	const float Scale{};

	LightCurlNoise(int32_t seed, float scale, int32_t octave);

	SIMD::Vec3f Get(SIMD::Vec3f pos) const;
};

} // namespace Effekseer

#endif