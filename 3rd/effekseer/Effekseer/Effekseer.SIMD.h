#pragma once

#ifndef __EFFEKSEER_SIMD_BASE_H__
#define __EFFEKSEER_SIMD_BASE_H__

#include <cstdint>
#include <cmath>

#if defined(__ARM_NEON__) || defined(__ARM_NEON)
// ARMv7/ARM64 NEON

#define EFK_SIMD_NEON

#if defined(_M_ARM64) || defined(__aarch64__)
#define EFK_SIMD_NEON_ARM64
#endif

#include <arm_neon.h>

#elif (defined(_M_AMD64) || defined(_M_X64)) || (defined(_M_IX86_FP) && _M_IX86_FP >= 2) || defined(__SSE2__)
// x86/x86-64 SSE2/AVX2

#define EFK_SIMD_SSE2

#if defined(__AVX2__)
#define EFK_SIMD_AVX2
#endif
#if defined(__AVX__) || defined(EFK_SIMD_AVX2)
#define EFK_SIMD_AVX
#endif
#if defined(__SSE4_2__) || defined(EFK_SIMD_AVX)
#define EFK_SIMD_SSE4_2
#endif
#if defined(__SSE4_1__) || defined(EFK_SIMD_SSE4_2)
#define EFK_SIMD_SSE4_1
#endif
#if defined(__SSSE3__) || defined(EFK_SIMD_SSE4_1)
#define EFK_SIMD_SSSE3
#endif
#if defined(__SSE3__) || defined(EFK_SIMD_SSSE3)
#define EFK_SIMD_SSE3
#endif

#if defined(EFK_SIMD_AVX) || defined(EFK_SIMD_AVX2)
#include <immintrin.h>
#elif defined(EFK_SIMD_SSE4_2)
#include <nmmintrin.h>
#elif defined(EFK_SIMD_SSE4_1)
#include <smmintrin.h>
#elif defined(EFK_SIMD_SSSE3)
#include <tmmintrin.h>
#elif defined(EFK_SIMD_SSE3)
#include <pmmintrin.h>
#elif defined(EFK_SIMD_SSE2)
#include <emmintrin.h>
#endif

#else
// C++ Generic Implementation (Pseudo SIMD)

#define EFK_SIMD_GEN

#endif

const float DefaultEpsilon = 1e-6f;

#endif // __EFFEKSEER_SIMD_BASE_H__

#ifndef __EFFEKSEER_SIMD_FLOAT4_GEN_H__
#define __EFFEKSEER_SIMD_FLOAT4_GEN_H__


#if defined(EFK_SIMD_GEN)

#include <cstring>
#include <algorithm>

namespace Effekseer
{
	
namespace SIMD
{

inline float Sqrt(float x)
{
	return std::sqrt(x);
}
inline float Rsqrt(float x)
{
	return 1.0f / std::sqrt(x);
}

struct Int4;

/**
	@brief	simd class for generic
*/
struct alignas(16) Float4
{
	union {
		float vf[4];
		int32_t vi[4];
		uint32_t vu[4];
	};

	Float4() = default;
	Float4(const Float4& rhs) = default;
	Float4(float x, float y, float z, float w) { vf[0] = x; vf[1] = y; vf[2] = z; vf[3] = w; }
	Float4(float i) { vf[0] = i; vf[1] = i; vf[2] = i; vf[3] = i; }

	float GetX() const { return vf[0]; }
	float GetY() const { return vf[1]; }
	float GetZ() const { return vf[2]; }
	float GetW() const { return vf[3]; }

	void SetX(float o) { vf[0] = o; }
	void SetY(float o) { vf[1] = o; }
	void SetZ(float o) { vf[2] = o; }
	void SetW(float o) { vf[3] = o; }

	template <size_t LANE>
	Float4 Dup() { return Float4(vf[LANE], vf[LANE], vf[LANE], vf[LANE]); }

	Int4 Convert4i() const;
	Int4 Cast4i() const;

	Float4& operator+=(const Float4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vf[i] += rhs.vf[i];
		}
		return *this;
	}

	Float4& operator-=(const Float4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vf[i] -= rhs.vf[i];
		}
		return *this;
	}

	Float4& operator*=(const Float4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vf[i] *= rhs.vf[i];
		}
		return *this;
	}

	Float4& operator*=(float rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vf[i] *= rhs;
		}
		return *this;
	}

	Float4& operator/=(const Float4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vf[i] /= rhs.vf[i];
		}
		return *this;
	}

	Float4& operator/=(float rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vf[i] /= rhs;
		}
		return *this;
	}

	static Float4 Load2(const void* mem);
	static void Store2(void* mem, const Float4& i);
	static Float4 Load3(const void* mem);
	static void Store3(void* mem, const Float4& i);
	static Float4 Load4(const void* mem);
	static void Store4(void* mem, const Float4& i);

	static Float4 SetZero();
	static Float4 SetInt(int32_t x, int32_t y, int32_t z, int32_t w);
	static Float4 SetUInt(uint32_t x, uint32_t y, uint32_t z, uint32_t w);
	static Float4 Sqrt(const Float4& in);
	static Float4 Rsqrt(const Float4& in);
	static Float4 Abs(const Float4& in);
	static Float4 Min(const Float4& lhs, const Float4& rhs);
	static Float4 Max(const Float4& lhs, const Float4& rhs);
	static Float4 Floor(const Float4& in);
	static Float4 Ceil(const Float4& in);
	static Float4 MulAdd(const Float4& a, const Float4& b, const Float4& c);
	static Float4 MulSub(const Float4& a, const Float4& b, const Float4& c);

	template<size_t LANE>
	static Float4 MulLane(const Float4& lhs, const Float4& rhs);
	template<size_t LANE>
	static Float4 MulAddLane(const Float4& a, const Float4& b, const Float4& c);
	template<size_t LANE>
	static Float4 MulSubLane(const Float4& a, const Float4& b, const Float4& c);
	template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
	static Float4 Swizzle(const Float4& in);

	static Float4 Dot3(const Float4& lhs, const Float4& rhs);
	static Float4 Cross3(const Float4& lhs, const Float4& rhs);

	template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
	static Float4 Mask();
	static uint32_t MoveMask(const Float4& in);
	static Float4 Select(const Float4& mask, const Float4& sel1, const Float4& sel2);
	static Float4 Equal(const Float4& lhs, const Float4& rhs);
	static Float4 NotEqual(const Float4& lhs, const Float4& rhs);
	static Float4 LessThan(const Float4& lhs, const Float4& rhs);
	static Float4 LessEqual(const Float4& lhs, const Float4& rhs);
	static Float4 GreaterThan(const Float4& lhs, const Float4& rhs);
	static Float4 GreaterEqual(const Float4& lhs, const Float4& rhs);
	static Float4 NearEqual(const Float4& lhs, const Float4& rhs, float epsilon = DefaultEpsilon);
	static Float4 IsZero(const Float4& in, float epsilon = DefaultEpsilon);
	static void Transpose(Float4& s0, Float4& s1, Float4& s2, Float4& s3);
};

inline Float4 operator+(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = lhs.vf[i] + rhs.vf[i];
	}
	return ret;
}

inline Float4 operator-(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = lhs.vf[i] - rhs.vf[i];
	}
	return ret;
}

inline Float4 operator*(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = lhs.vf[i] * rhs.vf[i];
	}
	return ret;
}

inline Float4 operator*(const Float4& lhs, float rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = lhs.vf[i] * rhs;
	}
	return ret;
}

inline Float4 operator/(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = lhs.vf[i] / rhs.vf[i];
	}
	return ret;
}

inline Float4 operator/(const Float4& lhs, float rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = lhs.vf[i] / rhs;
	}
	return ret;
}

inline Float4 operator&(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] & rhs.vu[i];
	}
	return ret;
}

inline Float4 operator|(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] | rhs.vu[i];
	}
	return ret;
}

inline Float4 operator^(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] ^ rhs.vu[i];
	}
	return ret;
}

inline bool operator==(const Float4& lhs, const Float4& rhs)
{
	bool ret = true;
	for (size_t i = 0; i < 4; i++)
	{
		ret &= lhs.vf[i] == rhs.vf[i];
	}
	return ret;
}

inline bool operator!=(const Float4& lhs, const Float4& rhs)
{
	bool ret = true;
	for (size_t i = 0; i < 4; i++)
	{
		ret &= lhs.vf[i] == rhs.vf[i];
	}
	return !ret;
}

inline Float4 Float4::Load2(const void* mem)
{
	Float4 ret;
	memcpy(ret.vf, mem, sizeof(float) * 2);
	// This code causes bugs in asmjs
	// ret.vf[0] = *((float*)mem + 0);
	// ret.vf[1] = *((float*)mem + 1);
	return ret;
}

inline void Float4::Store2(void* mem, const Float4& i)
{
	memcpy(mem, i.vf, sizeof(float) * 2);
	// This code causes bugs in asmjs
	// *((float*)mem + 0) = i.vf[0];
	// *((float*)mem + 1) = i.vf[1];
}

inline Float4 Float4::Load3(const void* mem)
{
	Float4 ret;
	memcpy(ret.vf, mem, sizeof(float) * 3);
	// This code causes bugs in asmjs
	// ret.vf[0] = *((float*)mem + 0);
	// ret.vf[1] = *((float*)mem + 1);
	// ret.vf[2] = *((float*)mem + 2);
	return ret;
}

inline void Float4::Store3(void* mem, const Float4& i)
{
	memcpy(mem, i.vf, sizeof(float) * 3);
	// This code causes bugs in asmjs
	// *((float*)mem + 0) = i.vf[0];
	// *((float*)mem + 1) = i.vf[1];
	// *((float*)mem + 2) = i.vf[2];
}

inline Float4 Float4::Load4(const void* mem)
{
	Float4 ret;
	memcpy(ret.vf, mem, sizeof(float) * 4);
	// This code causes bugs in emscripten
	// ret.vf[0] = *((float*)mem + 0);
	// ret.vf[1] = *((float*)mem + 1);
	// ret.vf[2] = *((float*)mem + 2);
	// ret.vf[3] = *((float*)mem + 3);
	return ret;
}

inline void Float4::Store4(void* mem, const Float4& i)
{
	memcpy(mem, i.vf, sizeof(float) * 4);
	// This code causes bugs in asmjs
	// *((float*)mem + 0) = i.vf[0];
	// *((float*)mem + 1) = i.vf[1];
	// *((float*)mem + 2) = i.vf[2];
	// *((float*)mem + 3) = i.vf[3];
}

inline Float4 Float4::SetZero()
{
	Float4 ret;
	ret.vf[0] = 0.0f;
	ret.vf[1] = 0.0f;
	ret.vf[2] = 0.0f;
	ret.vf[3] = 0.0f;
	return ret;
}

inline Float4 Float4::SetInt(int32_t x, int32_t y, int32_t z, int32_t w)
{
	Float4 ret;
	ret.vu[0] = (uint32_t)x;
	ret.vu[1] = (uint32_t)y;
	ret.vu[2] = (uint32_t)z;
	ret.vu[3] = (uint32_t)w;
	return ret;
}

inline Float4 Float4::SetUInt(uint32_t x, uint32_t y, uint32_t z, uint32_t w)
{
	Float4 ret;
	ret.vu[0] = (uint32_t)x;
	ret.vu[1] = (uint32_t)y;
	ret.vu[2] = (uint32_t)z;
	ret.vu[3] = (uint32_t)w;
	return ret;
}

inline Float4 Float4::Sqrt(const Float4& in)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = std::sqrt(in.vf[i]);
	}
	return ret;
}

inline Float4 Float4::Rsqrt(const Float4& in)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = 1.0f / std::sqrt(in.vf[i]);
	}
	return ret;
}

inline Float4 Float4::Abs(const Float4& in)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = std::abs(in.vf[i]);
	}
	return ret;
}

inline Float4 Float4::Min(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = std::fmin(lhs.vf[i], rhs.vf[i]);
	}
	return ret;
}

inline Float4 Float4::Max(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = std::fmax(lhs.vf[i], rhs.vf[i]);
	}
	return ret;
}

inline Float4 Float4::Floor(const Float4& in)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = std::floor(in.vf[i]);
	}
	return ret;
}

inline Float4 Float4::Ceil(const Float4& in)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = std::ceil(in.vf[i]);
	}
	return ret;
}

inline Float4 Float4::MulAdd(const Float4& a, const Float4& b, const Float4& c)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = a.vf[i] + b.vf[i] * c.vf[i];
}
	return ret;
}

inline Float4 Float4::MulSub(const Float4& a, const Float4& b, const Float4& c)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vf[i] = a.vf[i] - b.vf[i] * c.vf[i];
}
	return ret;
}

inline Float4 Float4::Dot3(const Float4& lhs, const Float4& rhs)
{
	Float4 muled = lhs * rhs;
	return Float4{muled.vf[0] + muled.vf[1] + muled.vf[2], 0.0f, 0.0f, 0.0f};
}

inline Float4 Float4::Cross3(const Float4& lhs, const Float4& rhs)
{
	return Float4::Swizzle<1,2,0,3>(lhs) * Float4::Swizzle<2,0,1,3>(rhs) -
		Float4::Swizzle<2,0,1,3>(lhs) * Float4::Swizzle<1,2,0,3>(rhs);
}

template<size_t LANE>
Float4 Float4::MulLane(const Float4& lhs, const Float4& rhs)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return lhs * rhs.vf[LANE];
}

template<size_t LANE>
Float4 Float4::MulAddLane(const Float4& a, const Float4& b, const Float4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return a + b * c.vf[LANE];
}

template<size_t LANE>
Float4 Float4::MulSubLane(const Float4& a, const Float4& b, const Float4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return a - b * c.vf[LANE];
}

template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
Float4 Float4::Swizzle(const Float4& in)
{
	static_assert(indexX < 4, "indexX is must be less than 4.");
	static_assert(indexY < 4, "indexY is must be less than 4.");
	static_assert(indexZ < 4, "indexZ is must be less than 4.");
	static_assert(indexW < 4, "indexW is must be less than 4.");
	return Float4{in.vf[indexX], in.vf[indexY], in.vf[indexZ], in.vf[indexW]};
}


template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
Float4 Float4::Mask()
{
	static_assert(X >= 2, "indexX is must be set 0 or 1.");
	static_assert(Y >= 2, "indexY is must be set 0 or 1.");
	static_assert(Z >= 2, "indexZ is must be set 0 or 1.");
	static_assert(W >= 2, "indexW is must be set 0 or 1.");
	Float4 ret;
	ret.vu[0] = 0xffffffff * X;
	ret.vu[1] = 0xffffffff * Y;
	ret.vu[2] = 0xffffffff * Z;
	ret.vu[3] = 0xffffffff * W;
	return ret;
}

inline uint32_t Float4::MoveMask(const Float4& in)
{
	return (in.vu[0] & 0x1) | (in.vu[1] & 0x2) | (in.vu[2] & 0x4) | (in.vu[3] & 0x8);
}

inline Float4 Float4::Select(const Float4& mask, const Float4& sel1, const Float4& sel2)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (mask.vu[i] & sel1.vu[i]) | (~mask.vu[i] & sel2.vu[i]);
	}
	return ret;
}

inline Float4 Float4::Equal(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vf[i] == rhs.vf[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::NotEqual(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vf[i] != rhs.vf[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::LessThan(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vf[i] < rhs.vf[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::LessEqual(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vf[i] <= rhs.vf[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::GreaterThan(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vf[i] > rhs.vf[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::GreaterEqual(const Float4& lhs, const Float4& rhs)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vf[i] >= rhs.vf[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::NearEqual(const Float4& lhs, const Float4& rhs, float epsilon)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (std::abs(lhs.vf[i] - rhs.vf[i]) <= epsilon) ? 0xffffffff : 0;
	}
	return ret;
}

inline Float4 Float4::IsZero(const Float4& in, float epsilon)
{
	Float4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (std::abs(in.vf[i]) <= epsilon) ? 0xffffffff : 0;
	}
	return ret;
}

inline void Float4::Transpose(Float4& s0, Float4& s1, Float4& s2, Float4& s3)
{
	std::swap(s0.vf[1], s1.vf[0]);
	std::swap(s0.vf[2], s2.vf[0]);
	std::swap(s0.vf[3], s3.vf[0]);
	std::swap(s1.vf[2], s2.vf[1]);
	std::swap(s2.vf[3], s3.vf[2]);
	std::swap(s1.vf[3], s3.vf[1]);
}

} // namespace SIMD

} // namespace Effekseer

#endif // defined(EFK_SIMD_GEN)

#endif // __EFFEKSEER_SIMD_FLOAT4_GEN_H__

#ifndef __EFFEKSEER_SIMD_FLOAT4_NEON_H__
#define __EFFEKSEER_SIMD_FLOAT4_NEON_H__


#if defined(EFK_SIMD_NEON)

namespace Effekseer
{
	
namespace SIMD
{

inline float Sqrt(float x)
{
	return sqrt(x);
}

inline float Rsqrt(float x)
{
	return 1.0f / sqrt(x);
}

struct Int4;

/**
 @brief    simd class for sse
 */

struct alignas(16) Float4
{
	float32x4_t s;
	
	Float4() = default;
	Float4(const Float4& rhs) = default;
	Float4(float32x4_t rhs) { s = rhs; }
	Float4(uint32x4_t rhs) { s = vreinterpretq_f32_u32(rhs); }
	Float4(float x, float y, float z, float w) { const float f[4] = {x, y, z, w}; s = vld1q_f32(f); }
	Float4(float i) { s = vdupq_n_f32(i); }
	
	float GetX() const { return vgetq_lane_f32(s, 0); }
	float GetY() const { return vgetq_lane_f32(s, 1); }
	float GetZ() const { return vgetq_lane_f32(s, 2); }
	float GetW() const { return vgetq_lane_f32(s, 3); }
	
	void SetX(float i) { s = vsetq_lane_f32(i, s, 0); }
	void SetY(float i) { s = vsetq_lane_f32(i, s, 1); }
	void SetZ(float i) { s = vsetq_lane_f32(i, s, 2); }
	void SetW(float i) { s = vsetq_lane_f32(i, s, 3); }
	
	template <size_t LANE>
	Float4 Dup();
	
	Int4 Convert4i() const;
	Int4 Cast4i() const;
	
	Float4& operator+=(const Float4& rhs);
	Float4& operator-=(const Float4& rhs);
	Float4& operator*=(const Float4& rhs);
	Float4& operator*=(float rhs);
	Float4& operator/=(const Float4& rhs);
	Float4& operator/=(float rhs);
	
	static Float4 Load2(const void* mem);
	static void Store2(void* mem, const Float4& i);
	static Float4 Load3(const void* mem);
	static void Store3(void* mem, const Float4& i);
	static Float4 Load4(const void* mem);
	static void Store4(void* mem, const Float4& i);
	
	static Float4 SetZero();
	static Float4 SetInt(int32_t x, int32_t y, int32_t z, int32_t w);
	static Float4 SetUInt(uint32_t x, uint32_t y, uint32_t z, uint32_t w);
	static Float4 Sqrt(const Float4& in);
	static Float4 Rsqrt(const Float4& in);
	static Float4 Abs(const Float4& in);
	static Float4 Min(const Float4& lhs, const Float4& rhs);
	static Float4 Max(const Float4& lhs, const Float4& rhs);
	static Float4 Floor(const Float4& in);
	static Float4 Ceil(const Float4& in);
	static Float4 MulAdd(const Float4& a, const Float4& b, const Float4& c);
	static Float4 MulSub(const Float4& a, const Float4& b, const Float4& c);
	
	template<size_t LANE>
	static Float4 MulLane(const Float4& lhs, const Float4& rhs);
	template<size_t LANE>
	static Float4 MulAddLane(const Float4& a, const Float4& b, const Float4& c);
	template<size_t LANE>
	static Float4 MulSubLane(const Float4& a, const Float4& b, const Float4& c);
	template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
	static Float4 Swizzle(const Float4& v);
	
	static Float4 Dot3(const Float4& lhs, const Float4& rhs);
	static Float4 Cross3(const Float4& lhs, const Float4& rhs);
	
	template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
	static Float4 Mask();
	static uint32_t MoveMask(const Float4& in);
	static Float4 Select(const Float4& mask, const Float4& sel1, const Float4& sel2);
	static Float4 Equal(const Float4& lhs, const Float4& rhs);
	static Float4 NotEqual(const Float4& lhs, const Float4& rhs);
	static Float4 LessThan(const Float4& lhs, const Float4& rhs);
	static Float4 LessEqual(const Float4& lhs, const Float4& rhs);
	static Float4 GreaterThan(const Float4& lhs, const Float4& rhs);
	static Float4 GreaterEqual(const Float4& lhs, const Float4& rhs);
	static Float4 NearEqual(const Float4& lhs, const Float4& rhs, float epsilon = DefaultEpsilon);
	static Float4 IsZero(const Float4& in, float epsilon = DefaultEpsilon);
	static void Transpose(Float4& s0, Float4& s1, Float4& s2, Float4& s3);
	
private:
	static Float4 SwizzleYZX(const Float4& in);
	static Float4 SwizzleZXY(const Float4& in);
};

template <size_t LANE>
Float4 Float4::Dup()
{
	return (LANE < 2) ?
		vdupq_lane_f32(vget_low_f32(s), LANE) :
		vdupq_lane_f32(vget_high_f32(s), LANE & 1);
}

inline Float4 operator+(const Float4& lhs, const Float4& rhs)
{
	return vaddq_f32(lhs.s, rhs.s);
}

inline Float4 operator-(const Float4& lhs, const Float4& rhs)
{
	return vsubq_f32(lhs.s, rhs.s);
}

inline Float4 operator*(const Float4& lhs, const Float4& rhs)
{
	return vmulq_f32(lhs.s, rhs.s);
}

inline Float4 operator*(const Float4& lhs, float rhs)
{
	return vmulq_n_f32(lhs.s, rhs);
}

inline Float4 operator/(const Float4& lhs, const Float4& rhs)
{
#if defined(_M_ARM64) || __aarch64__
	return vdivq_f32(lhs.s, rhs.s);
#else
	float32x4_t recp = vrecpeq_f32(rhs.s);
	float32x4_t s = vrecpsq_f32(recp, rhs.s);
	recp = vmulq_f32(s, recp);
	s = vrecpsq_f32(recp, rhs.s);
	recp = vmulq_f32(s, recp);
	return vmulq_f32(lhs.s, recp);
#endif
}

inline Float4 operator/(const Float4& lhs, float rhs)
{
	return lhs * (1.0f / rhs);
}

inline Float4 operator&(const Float4& lhs, const Float4& rhs)
{
	uint32x4_t lhsi = vreinterpretq_u32_f32(lhs.s);
	uint32x4_t rhsi = vreinterpretq_u32_f32(rhs.s);
	return vreinterpretq_f32_u32(vandq_u32(lhsi, rhsi));
}

inline Float4 operator|(const Float4& lhs, const Float4& rhs)
{
	uint32x4_t lhsi = vreinterpretq_u32_f32(lhs.s);
	uint32x4_t rhsi = vreinterpretq_u32_f32(rhs.s);
	return vreinterpretq_f32_u32(vorrq_u32(lhsi, rhsi));
}

inline Float4 operator^(const Float4& lhs, const Float4& rhs)
{
	uint32x4_t lhsi = vreinterpretq_u32_f32(lhs.s);
	uint32x4_t rhsi = vreinterpretq_u32_f32(rhs.s);
	return vreinterpretq_f32_u32(veorq_u32(lhsi, rhsi));
}

inline bool operator==(const Float4& lhs, const Float4& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs, rhs)) == 0xf;
}

inline bool operator!=(const Float4& lhs, const Float4& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs, rhs)) != 0xf;
}

inline Float4& Float4::operator+=(const Float4& rhs) { return *this = *this + rhs; }
inline Float4& Float4::operator-=(const Float4& rhs) { return *this = *this - rhs; }
inline Float4& Float4::operator*=(const Float4& rhs) { return *this = *this * rhs; }
inline Float4& Float4::operator*=(float rhs) { return *this = *this * rhs; }
inline Float4& Float4::operator/=(const Float4& rhs) { return *this = *this / rhs; }
inline Float4& Float4::operator/=(float rhs) { return *this = *this / rhs; }

inline Float4 Float4::Load2(const void* mem)
{
	float32x2_t low = vld1_f32((const float*)mem);
	float32x2_t high = vdup_n_f32(0.0f);
	return vcombine_f32(low, high);
}

inline void Float4::Store2(void* mem, const Float4& i)
{
	vst1_f32((float*)mem, vget_low_f32(i.s));
}

inline Float4 Float4::Load3(const void* mem)
{
	float32x2_t low = vld1_f32((const float*)mem);
	float32x2_t high = vld1_lane_f32((const float*)mem + 2, vdup_n_f32(0.0f), 0);
	return vcombine_f32(low, high);
}

inline void Float4::Store3(void* mem, const Float4& i)
{
	vst1_f32((float*)mem, vget_low_f32(i.s));
	vst1q_lane_f32((float*)mem + 2, i.s, 2);
}

inline Float4 Float4::Load4(const void* mem)
{
	return vld1q_f32((const float*)mem);
}

inline void Float4::Store4(void* mem, const Float4& i)
{
	vst1q_f32((float*)mem, i.s);
}

inline Float4 Float4::SetZero()
{
	return vdupq_n_f32(0.0f);
}

inline Float4 Float4::SetInt(int32_t x, int32_t y, int32_t z, int32_t w)
{
	const int32_t i[4] = {x, y, z, w};
	return vreinterpretq_f32_s32(vld1q_s32(i));
}

inline Float4 Float4::SetUInt(uint32_t x, uint32_t y, uint32_t z, uint32_t w)
{
	const uint32_t i[4] = {x, y, z, w};
	return vreinterpretq_u32_f32(vld1q_u32(i));
}

inline Float4 Float4::Sqrt(const Float4& in)
{
#if defined(_M_ARM64) || __aarch64__
	return vsqrtq_f32(in.s);
#else
	return Float4(1.0f) / Float4::Rsqrt(in);
#endif
}

inline Float4 Float4::Rsqrt(const Float4& in)
{
	float32x4_t s0 = vrsqrteq_f32(in.s);
	float32x4_t p0 = vmulq_f32(in.s, s0);
	float32x4_t r0 = vrsqrtsq_f32(p0, s0);
	float32x4_t s1 = vmulq_f32(s0, r0);
	return s1;
}

inline Float4 Float4::Abs(const Float4& in)
{
	return vabsq_f32(in.s);
}

inline Float4 Float4::Min(const Float4& lhs, const Float4& rhs)
{
	return vminq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::Max(const Float4& lhs, const Float4& rhs)
{
	return vmaxq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::Floor(const Float4& in)
{
#if defined(_M_ARM64) || __aarch64__
	return vrndmq_f32(in.s);
#else
	int32x4_t in_i = vcvtq_s32_f32(in.s);
	float32x4_t result = vcvtq_f32_s32(in_i);
	float32x4_t larger = vcgtq_f32(result, in.s);
	larger = vcvtq_f32_s32(larger);
	return vaddq_f32(result, larger);
#endif
}

inline Float4 Float4::Ceil(const Float4& in)
{
#if defined(_M_ARM64) || __aarch64__
	return vrndpq_f32(in.s);
#else
	int32x4_t in_i = vcvtq_s32_f32(in.s);
	float32x4_t result = vcvtq_f32_s32(in_i);
	float32x4_t smaller = vcltq_f32(result, in.s);
	smaller = vcvtq_f32_s32(smaller);
	return vsubq_f32(result, smaller);
#endif
}

inline Float4 Float4::MulAdd(const Float4& a, const Float4& b, const Float4& c)
{
	return vmlaq_f32(a.s, b.s, c.s);
}

inline Float4 Float4::MulSub(const Float4& a, const Float4& b, const Float4& c)
{
	return vmlsq_f32(a.s, b.s, c.s);
}

template<size_t LANE>
inline Float4 Float4::MulLane(const Float4& lhs, const Float4& rhs)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	float32x2_t rhs2 = (LANE < 2) ? vget_low_f32(rhs.s) : vget_high_f32(rhs.s);
	return vmulq_lane_f32(lhs.s, rhs2, LANE & 1);
}

template<size_t LANE>
inline Float4 Float4::MulAddLane(const Float4& a, const Float4& b, const Float4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	float32x2_t c2 = (LANE < 2) ? vget_low_f32(c.s) : vget_high_f32(c.s);
	return vmlaq_lane_f32(a.s, b.s, c2, LANE & 1);
}

template<size_t LANE>
inline Float4 Float4::MulSubLane(const Float4& a, const Float4& b, const Float4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	float32x2_t c2 = (LANE < 2) ? vget_low_f32(c.s) : vget_high_f32(c.s);
	return vmlsq_lane_f32(a.s, b.s, c2, LANE & 1);
}

//template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
//inline Float4 Float4::Swizzle(const Float4& v)
//{
//	static_assert(indexX < 4, "indexX is must be less than 4.");
//	static_assert(indexY < 4, "indexY is must be less than 4.");
//	static_assert(indexZ < 4, "indexZ is must be less than 4.");
//	static_assert(indexW < 4, "indexW is must be less than 4.");
//}

inline Float4 Float4::Dot3(const Float4& lhs, const Float4& rhs)
{
	float32x4_t mul = vmulq_f32(lhs.s, rhs.s);
	float32x2_t xy = vpadd_f32(vget_low_f32(mul), vget_low_f32(mul));
	float32x2_t dot = vadd_f32(xy, vget_high_f32(mul));
	return vcombine_f32(dot, vdup_n_f32(0.0f));
}

inline Float4 Float4::Cross3(const Float4& lhs, const Float4& rhs)
{
	return MulSub(SwizzleYZX(lhs.s) * SwizzleZXY(rhs.s), SwizzleZXY(lhs.s), SwizzleYZX(rhs.s));
}

template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
inline Float4 Float4::Mask()
{
	static_assert(X >= 2, "indexX is must be set 0 or 1.");
	static_assert(Y >= 2, "indexY is must be set 0 or 1.");
	static_assert(Z >= 2, "indexZ is must be set 0 or 1.");
	static_assert(W >= 2, "indexW is must be set 0 or 1.");
	const uint32_t in[4] = {0xffffffff * X, 0xffffffff * Y, 0xffffffff * Z, 0xffffffff * W};
	return vld1q_f32((const float*)in);
}

inline uint32_t Float4::MoveMask(const Float4& in)
{
	uint16x4_t u16x4 = vmovn_u32(vreinterpretq_u32_f32(in.s));
	uint16_t u16[4];
	vst1_u16(u16, u16x4);
	return (u16[0] & 1) | (u16[1] & 2) | (u16[2] & 4) | (u16[3] & 8);
}

inline Float4 Float4::Select(const Float4& mask, const Float4& sel1, const Float4& sel2)
{
	uint32x4_t maski = vreinterpretq_u32_f32(mask.s);
	return vbslq_f32(maski, sel1.s, sel2.s);
}

inline Float4 Float4::Equal(const Float4& lhs, const Float4& rhs)
{
	return vceqq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::NotEqual(const Float4& lhs, const Float4& rhs)
{
	return vmvnq_u32(vceqq_f32(lhs.s, rhs.s));
}

inline Float4 Float4::LessThan(const Float4& lhs, const Float4& rhs)
{
	return vcltq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::LessEqual(const Float4& lhs, const Float4& rhs)
{
	return vcleq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::GreaterThan(const Float4& lhs, const Float4& rhs)
{
	return vcgtq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::GreaterEqual(const Float4& lhs, const Float4& rhs)
{
	return vcgeq_f32(lhs.s, rhs.s);
}

inline Float4 Float4::NearEqual(const Float4& lhs, const Float4& rhs, float epsilon)
{
	return LessEqual(Abs(lhs - rhs), Float4(epsilon));
}

inline Float4 Float4::IsZero(const Float4& in, float epsilon)
{
	return LessEqual(Abs(in), Float4(epsilon));
}

inline void Float4::Transpose(Float4& s0, Float4& s1, Float4& s2, Float4& s3)
{
	float32x4x2_t t0 = vzipq_f32(s0.s, s2.s);
	float32x4x2_t t1 = vzipq_f32(s1.s, s3.s);
	float32x4x2_t t2 = vzipq_f32(t0.val[0], t1.val[0]);
	float32x4x2_t t3 = vzipq_f32(t0.val[1], t1.val[1]);
	
	s0 = t2.val[0];
	s1 = t2.val[1];
	s2 = t3.val[0];
	s3 = t3.val[1];
}

inline Float4 Float4::SwizzleYZX(const Float4& in)
{
	float32x4_t ex = vextq_f32(in.s, in.s, 1);
	return vsetq_lane_f32(vgetq_lane_f32(ex, 3), ex, 2);
}

inline Float4 Float4::SwizzleZXY(const Float4& in)
{
	float32x4_t ex = vextq_f32(in.s, in.s, 3);
	return vsetq_lane_f32(vgetq_lane_f32(ex, 3), ex, 0);
}

} // namespace SIMD

} // namespace Effekseer

#endif
#endif // __EFFEKSEER_SIMD_FLOAT4_NEON_H__

#ifndef __EFFEKSEER_SIMD_FLOAT4_SSE_H__
#define __EFFEKSEER_SIMD_FLOAT4_SSE_H__


#if defined(EFK_SIMD_SSE2)

namespace Effekseer
{
	
namespace SIMD
{

inline float Sqrt(float x)
{
	_mm_store_ss(&x, _mm_sqrt_ss(_mm_load_ss(&x)));
	return x;
}
inline float Rsqrt(float x)
{
	_mm_store_ss(&x, _mm_rsqrt_ss(_mm_load_ss(&x)));
	return x;
}

struct Int4;

/**
	@brief	simd class for sse
*/

struct alignas(16) Float4
{
	__m128 s;

	Float4() = default;
	Float4(const Float4& rhs) = default;
	Float4(__m128 rhs) { s = rhs; }
	Float4(__m128i rhs) { s = _mm_castsi128_ps(rhs); }
	Float4(float x, float y, float z, float w) { s = _mm_setr_ps(x, y, z, w); }
	Float4(float i) { s = _mm_set_ps1(i); }

	float GetX() const { return _mm_cvtss_f32(s); }
	float GetY() const { return _mm_cvtss_f32(Swizzle<1,1,1,1>(s).s); }
	float GetZ() const { return _mm_cvtss_f32(Swizzle<2,2,2,2>(s).s); }
	float GetW() const { return _mm_cvtss_f32(Swizzle<3,3,3,3>(s).s); }

	void SetX(float i) { s = _mm_move_ss(s, _mm_set_ss(i)); }
	void SetY(float i) { s = Swizzle<1,0,2,3>(_mm_move_ss(Swizzle<1,0,2,3>(s).s, _mm_set_ss(i))).s; }
	void SetZ(float i) { s = Swizzle<2,1,0,3>(_mm_move_ss(Swizzle<2,1,0,3>(s).s, _mm_set_ss(i))).s; }
	void SetW(float i) { s = Swizzle<3,1,2,0>(_mm_move_ss(Swizzle<3,1,2,0>(s).s, _mm_set_ss(i))).s; }

	template <size_t LANE>
	Float4 Dup() { return Swizzle<LANE,LANE,LANE,LANE>(s); }

	Int4 Convert4i() const;
	Int4 Cast4i() const;

	Float4& operator+=(const Float4& rhs);
	Float4& operator-=(const Float4& rhs);
	Float4& operator*=(const Float4& rhs);
	Float4& operator*=(float rhs);
	Float4& operator/=(const Float4& rhs);
	Float4& operator/=(float rhs);

	static Float4 Load2(const void* mem);
	static void Store2(void* mem, const Float4& i);
	static Float4 Load3(const void* mem);
	static void Store3(void* mem, const Float4& i);
	static Float4 Load4(const void* mem);
	static void Store4(void* mem, const Float4& i);

	static Float4 SetZero();
	static Float4 SetInt(int32_t x, int32_t y, int32_t z, int32_t w);
	static Float4 SetUInt(uint32_t x, uint32_t y, uint32_t z, uint32_t w);
	static Float4 Sqrt(const Float4& in);
	static Float4 Rsqrt(const Float4& in);
	static Float4 Abs(const Float4& in);
	static Float4 Min(const Float4& lhs, const Float4& rhs);
	static Float4 Max(const Float4& lhs, const Float4& rhs);
	static Float4 Floor(const Float4& in);
	static Float4 Ceil(const Float4& in);
	static Float4 MulAdd(const Float4& a, const Float4& b, const Float4& c);
	static Float4 MulSub(const Float4& a, const Float4& b, const Float4& c);

	template<size_t LANE>
	static Float4 MulLane(const Float4& lhs, const Float4& rhs);
	template<size_t LANE>
	static Float4 MulAddLane(const Float4& a, const Float4& b, const Float4& c);
	template<size_t LANE>
	static Float4 MulSubLane(const Float4& a, const Float4& b, const Float4& c);
	template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
	static Float4 Swizzle(const Float4& v);

	static Float4 Dot3(const Float4& lhs, const Float4& rhs);
	static Float4 Cross3(const Float4& lhs, const Float4& rhs);

	template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
	static Float4 Mask();
	static uint32_t MoveMask(const Float4& in);
	static Float4 Select(const Float4& mask, const Float4& sel1, const Float4& sel2);
	static Float4 Equal(const Float4& lhs, const Float4& rhs);
	static Float4 NotEqual(const Float4& lhs, const Float4& rhs);
	static Float4 LessThan(const Float4& lhs, const Float4& rhs);
	static Float4 LessEqual(const Float4& lhs, const Float4& rhs);
	static Float4 GreaterThan(const Float4& lhs, const Float4& rhs);
	static Float4 GreaterEqual(const Float4& lhs, const Float4& rhs);
	static Float4 NearEqual(const Float4& lhs, const Float4& rhs, float epsilon = DefaultEpsilon);
	static Float4 IsZero(const Float4& in, float epsilon = DefaultEpsilon);
	static void Transpose(Float4& s0, Float4& s1, Float4& s2, Float4& s3);
};

inline Float4 operator+(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_add_ps(lhs.s, rhs.s)};
}

inline Float4 operator-(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_sub_ps(lhs.s, rhs.s)};
}

inline Float4 operator*(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_mul_ps(lhs.s, rhs.s)};
}

inline Float4 operator*(const Float4& lhs, float rhs)
{
	return Float4{_mm_mul_ps(lhs.s, _mm_set1_ps(rhs))};
}

inline Float4 operator/(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_div_ps(lhs.s, rhs.s)};
}

inline Float4 operator/(const Float4& lhs, float rhs)
{
	return Float4{_mm_div_ps(lhs.s, _mm_set1_ps(rhs))};
}

inline Float4 operator&(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_and_ps(lhs.s, rhs.s)};
}

inline Float4 operator|(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_or_ps(lhs.s, rhs.s)};
}

inline Float4 operator^(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_xor_ps(lhs.s, rhs.s)};
}

inline bool operator==(const Float4& lhs, const Float4& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs, rhs)) == 0xf;
}

inline bool operator!=(const Float4& lhs, const Float4& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs, rhs)) != 0xf;
}

inline Float4& Float4::operator+=(const Float4& rhs) { return *this = *this + rhs; }
inline Float4& Float4::operator-=(const Float4& rhs) { return *this = *this - rhs; }
inline Float4& Float4::operator*=(const Float4& rhs) { return *this = *this * rhs; }
inline Float4& Float4::operator*=(float rhs) { return *this = *this * rhs; }
inline Float4& Float4::operator/=(const Float4& rhs) { return *this = *this / rhs; }
inline Float4& Float4::operator/=(float rhs) { return *this = *this / rhs; }

inline Float4 Float4::Load2(const void* mem)
{
	__m128 x = _mm_load_ss((const float*)mem + 0);
	__m128 y = _mm_load_ss((const float*)mem + 1);
	return _mm_unpacklo_ps(x, y);
}

inline void Float4::Store2(void* mem, const Float4& i)
{
	Float4 t1 = Swizzle<1,1,1,1>(i.s);
	_mm_store_ss((float*)mem + 0, i.s);
	_mm_store_ss((float*)mem + 1, t1.s);
}

inline Float4 Float4::Load3(const void* mem)
{
	__m128 x = _mm_load_ss((const float*)mem + 0);
	__m128 y = _mm_load_ss((const float*)mem + 1);
	__m128 z = _mm_load_ss((const float*)mem + 2);
	__m128 xy = _mm_unpacklo_ps(x, y);
	return _mm_movelh_ps(xy, z);
}

inline void Float4::Store3(void* mem, const Float4& i)
{
	Float4 t1 = Swizzle<1,1,1,1>(i.s);
	Float4 t2 = Swizzle<2,2,2,2>(i.s);
	_mm_store_ss((float*)mem + 0, i.s);
	_mm_store_ss((float*)mem + 1, t1.s);
	_mm_store_ss((float*)mem + 2, t2.s);
}

inline Float4 Float4::Load4(const void* mem)
{
	return _mm_loadu_ps((const float*)mem);
}

inline void Float4::Store4(void* mem, const Float4& i)
{
	_mm_storeu_ps((float*)mem, i.s);
}

inline Float4 Float4::SetZero()
{
	return _mm_setzero_ps();
}

inline Float4 Float4::SetInt(int32_t x, int32_t y, int32_t z, int32_t w)
{
	return Float4{_mm_setr_epi32((int)x, (int)y, (int)z, (int)w)};
}

inline Float4 Float4::SetUInt(uint32_t x, uint32_t y, uint32_t z, uint32_t w)
{
	return Float4{_mm_setr_epi32((int)x, (int)y, (int)z, (int)w)};
}

inline Float4 Float4::Sqrt(const Float4& in)
{
	return Float4{_mm_sqrt_ps(in.s)};
}

inline Float4 Float4::Rsqrt(const Float4& in)
{
	return Float4{_mm_rsqrt_ps(in.s)};
}

inline Float4 Float4::Abs(const Float4& in)
{
	return _mm_andnot_ps(_mm_set1_ps(-0.0f), in.s);
}

inline Float4 Float4::Min(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_min_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::Max(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_max_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::Floor(const Float4& in)
{
#if defined(EFK_SIMD_SSE4_2)
	return _mm_floor_ps(in.s);
#else
	__m128i in_i = _mm_cvttps_epi32(in.s);
	__m128 result = _mm_cvtepi32_ps(in_i);
	__m128 larger = _mm_cmpgt_ps(result, in.s);
	larger = _mm_cvtepi32_ps(_mm_castps_si128(larger));
	return _mm_add_ps(result, larger);
#endif
}

inline Float4 Float4::Ceil(const Float4& in)
{
#if defined(EFK_SIMD_SSE4_2)
	return _mm_ceil_ps(in.s);
#else
	__m128i in_i = _mm_cvttps_epi32(in.s);
	__m128 result = _mm_cvtepi32_ps(in_i);
	__m128 smaller = _mm_cmplt_ps(result, in.s);
	smaller = _mm_cvtepi32_ps(_mm_castps_si128(smaller));
	return _mm_sub_ps(result, smaller);
#endif
}

inline Float4 Float4::MulAdd(const Float4& a, const Float4& b, const Float4& c)
{
#if defined(EFK_SIMD_AVX2)
	return Float4{_mm_fmadd_ps(b.s, c.s, a.s)};
#else
	return Float4{_mm_add_ps(a.s, _mm_mul_ps(b.s, c.s))};
#endif
}

inline Float4 Float4::MulSub(const Float4& a, const Float4& b, const Float4& c)
{
#if defined(EFK_SIMD_AVX2)
	return Float4{_mm_fnmadd_ps(b.s, c.s, a.s)};
#else
	return Float4{_mm_sub_ps(a.s, _mm_mul_ps(b.s, c.s))};
#endif
}

template<size_t LANE>
Float4 Float4::MulLane(const Float4& lhs, const Float4& rhs)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return _mm_mul_ps(lhs.s, Swizzle<LANE,LANE,LANE,LANE>(rhs).s);
}

template<size_t LANE>
Float4 Float4::MulAddLane(const Float4& a, const Float4& b, const Float4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
#if defined(EFK_SIMD_AVX2)
	return _mm_fmadd_ps(b.s, Swizzle<LANE,LANE,LANE,LANE>(c).s, a.s);
#else
	return _mm_add_ps(a.s, _mm_mul_ps(b.s, Swizzle<LANE,LANE,LANE,LANE>(c).s));
#endif
}

template<size_t LANE>
Float4 Float4::MulSubLane(const Float4& a, const Float4& b, const Float4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
#if defined(EFK_SIMD_AVX2)
	return _mm_fnmadd_ps(b.s, Swizzle<LANE,LANE,LANE,LANE>(c).s, a.s);
#else
	return _mm_sub_ps(a.s, _mm_mul_ps(b.s, Swizzle<LANE,LANE,LANE,LANE>(c).s));
#endif
}

template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
Float4 Float4::Swizzle(const Float4& v)
{
	static_assert(indexX < 4, "indexX is must be less than 4.");
	static_assert(indexY < 4, "indexY is must be less than 4.");
	static_assert(indexZ < 4, "indexZ is must be less than 4.");
	static_assert(indexW < 4, "indexW is must be less than 4.");

#if defined(EFK_SIMD_AVX)
	return _mm_permute_ps(v.s, _MM_SHUFFLE(indexW, indexZ, indexY, indexX));
#else
	return _mm_shuffle_ps(v.s, v.s, _MM_SHUFFLE(indexW, indexZ, indexY, indexX));
#endif
}

inline Float4 Float4::Dot3(const Float4& lhs, const Float4& rhs)
{
	Float4 muled = lhs * rhs;
	return _mm_add_ss(_mm_add_ss(muled.s, Float4::Swizzle<1,1,1,1>(muled).s), Float4::Swizzle<2,2,2,2>(muled).s);
}

inline Float4 Float4::Cross3(const Float4& lhs, const Float4& rhs)
{
	return Float4::Swizzle<1,2,0,3>(lhs) * Float4::Swizzle<2,0,1,3>(rhs) -
		Float4::Swizzle<2,0,1,3>(lhs) * Float4::Swizzle<1,2,0,3>(rhs);
}

template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
inline Float4 Float4::Mask()
{
	static_assert(X >= 2, "indexX is must be set 0 or 1.");
	static_assert(Y >= 2, "indexY is must be set 0 or 1.");
	static_assert(Z >= 2, "indexZ is must be set 0 or 1.");
	static_assert(W >= 2, "indexW is must be set 0 or 1.");
	return _mm_setr_epi32(
		(int)(0xffffffff * X), 
		(int)(0xffffffff * Y), 
		(int)(0xffffffff * Z), 
		(int)(0xffffffff * W));
}

inline uint32_t Float4::MoveMask(const Float4& in)
{
	return (uint32_t)_mm_movemask_ps(in.s);
}

inline Float4 Float4::Select(const Float4& mask, const Float4& sel1, const Float4& sel2)
{
	return _mm_or_ps(_mm_and_ps(mask.s, sel1.s), _mm_andnot_ps(mask.s, sel2.s));
}

inline Float4 Float4::Equal(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_cmpeq_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::NotEqual(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_cmpneq_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::LessThan(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_cmplt_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::LessEqual(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_cmple_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::GreaterThan(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_cmpgt_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::GreaterEqual(const Float4& lhs, const Float4& rhs)
{
	return Float4{_mm_cmpge_ps(lhs.s, rhs.s)};
}

inline Float4 Float4::NearEqual(const Float4& lhs, const Float4& rhs, float epsilon)
{
	return LessEqual(Abs(lhs - rhs), Float4(epsilon));
}

inline Float4 Float4::IsZero(const Float4& in, float epsilon)
{
	return LessEqual(Abs(in), Float4(epsilon));
}

inline void Float4::Transpose(Float4& s0, Float4& s1, Float4& s2, Float4& s3)
{
	_MM_TRANSPOSE4_PS(s0.s, s1.s, s2.s, s3.s);
}

} // namespace SIMD

} // namespace Effekseer

#endif

#endif // __EFFEKSEER_SIMD_FLOAT4_SSE_H__

#ifndef __EFFEKSEER_SIMD_INT4_GEN_H__
#define __EFFEKSEER_SIMD_INT4_GEN_H__


#if defined(EFK_SIMD_GEN)

#include <cstring>
#include <algorithm>

namespace Effekseer
{
	
namespace SIMD
{

struct Float4;

/**
	@brief	simd class for generic
*/
struct alignas(16) Int4
{
	union {
		float vf[4];
		int32_t vi[4];
		uint32_t vu[4];
	};

	Int4() = default;
	Int4(const Int4& rhs) = default;
	Int4(int32_t x, int32_t y, int32_t z, int32_t w) { vi[0] = x; vi[1] = y; vi[2] = z; vi[3] = w; }
	Int4(int32_t i) { vi[0] = i; vi[1] = i; vi[2] = i; vi[3] = i; }

	int32_t GetX() const { return vi[0]; }
	int32_t GetY() const { return vi[1]; }
	int32_t GetZ() const { return vi[2]; }
	int32_t GetW() const { return vi[3]; }

	void SetX(int32_t o) { vi[0] = o; }
	void SetY(int32_t o) { vi[1] = o; }
	void SetZ(int32_t o) { vi[2] = o; }
	void SetW(int32_t o) { vi[3] = o; }

	Float4 Convert4f() const;
	Float4 Cast4f() const;

	Int4& operator+=(const Int4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vi[i] += rhs.vi[i];
		}
		return *this;
	}

	Int4& operator-=(const Int4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vi[i] -= rhs.vi[i];
		}
		return *this;
	}

	Int4& operator*=(const Int4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vi[i] *= rhs.vi[i];
		}
		return *this;
	}

	Int4& operator*=(int32_t rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vi[i] *= rhs;
		}
		return *this;
	}

	Int4& operator/=(const Int4& rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vi[i] /= rhs.vi[i];
		}
		return *this;
	}

	Int4& operator/=(int32_t rhs)
	{
		for (size_t i = 0; i < 4; i++)
		{
			vi[i] /= rhs;
		}
		return *this;
	}

	static Int4 Load2(const void* mem);
	static void Store2(void* mem, const Int4& i);
	static Int4 Load3(const void* mem);
	static void Store3(void* mem, const Int4& i);
	static Int4 Load4(const void* mem);
	static void Store4(void* mem, const Int4& i);

	static Int4 SetZero();
	static Int4 Abs(const Int4& in);
	static Int4 Min(const Int4& lhs, const Int4& rhs);
	static Int4 Max(const Int4& lhs, const Int4& rhs);
	static Int4 MulAdd(const Int4& a, const Int4& b, const Int4& c);
	static Int4 MulSub(const Int4& a, const Int4& b, const Int4& c);

	template<size_t LANE>
	static Int4 MulLane(const Int4& lhs, const Int4& rhs);
	template<size_t LANE>
	static Int4 MulAddLane(const Int4& a, const Int4& b, const Int4& c);
	template<size_t LANE>
	static Int4 MulSubLane(const Int4& a, const Int4& b, const Int4& c);
	template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
	static Int4 Swizzle(const Int4& in);

	template <int COUNT>
	static Int4 ShiftL(const Int4& in);
	template <int COUNT>
	static Int4 ShiftR(const Int4& in);
	template <int COUNT>
	static Int4 ShiftRA(const Int4& in);

	template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
	static Int4 Mask();
	static uint32_t MoveMask(const Int4& in);
	static Int4 Equal(const Int4& lhs, const Int4& rhs);
	static Int4 NotEqual(const Int4& lhs, const Int4& rhs);
	static Int4 LessThan(const Int4& lhs, const Int4& rhs);
	static Int4 LessEqual(const Int4& lhs, const Int4& rhs);
	static Int4 GreaterThan(const Int4& lhs, const Int4& rhs);
	static Int4 GreaterEqual(const Int4& lhs, const Int4& rhs);
	static Int4 NearEqual(const Int4& lhs, const Int4& rhs, float epsilon = DefaultEpsilon);
	static Int4 IsZero(const Int4& in, float epsilon = DefaultEpsilon);
	static void Transpose(Int4& s0, Int4& s1, Int4& s2, Int4& s3);
};

inline Int4 operator+(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] + rhs.vi[i];
	}
	return ret;
}

inline Int4 operator-(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] - rhs.vi[i];
	}
	return ret;
}

inline Int4 operator*(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] * rhs.vi[i];
	}
	return ret;
}

inline Int4 operator*(const Int4& lhs, int32_t rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] * rhs;
	}
	return ret;
}

inline Int4 operator/(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] / rhs.vi[i];
	}
	return ret;
}

inline Int4 operator/(const Int4& lhs, int32_t rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] / rhs;
	}
	return ret;
}

inline Int4 operator&(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] & rhs.vu[i];
	}
	return ret;
}

inline Int4 operator|(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] | rhs.vu[i];
	}
	return ret;
}

inline Int4 operator^(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] ^ rhs.vu[i];
	}
	return ret;
}

inline bool operator==(const Int4& lhs, const Int4& rhs)
{
	bool ret = true;
	for (size_t i = 0; i < 4; i++)
	{
		ret &= lhs.vi[i] == rhs.vi[i];
	}
	return ret;
}

inline bool operator!=(const Int4& lhs, const Int4& rhs)
{
	bool ret = true;
	for (size_t i = 0; i < 4; i++)
	{
		ret &= lhs.vi[i] == rhs.vi[i];
	}
	return !ret;
}

inline Int4 Int4::Load2(const void* mem)
{
	Int4 ret;
	memcpy(ret.vi, mem, sizeof(float) * 2);
	// This code causes bugs in asmjs
	// ret.vi[0] = *((float*)mem + 0);
	// ret.vi[1] = *((float*)mem + 1);
	return ret;
}

inline void Int4::Store2(void* mem, const Int4& i)
{
	memcpy(mem, i.vi, sizeof(float) * 2);
	// This code causes bugs in asmjs
	// *((float*)mem + 0) = i.vi[0];
	// *((float*)mem + 1) = i.vi[1];
}

inline Int4 Int4::Load3(const void* mem)
{
	Int4 ret;
	memcpy(ret.vi, mem, sizeof(float) * 3);
	// This code causes bugs in asmjs
	// ret.vi[0] = *((float*)mem + 0);
	// ret.vi[1] = *((float*)mem + 1);
	// ret.vi[2] = *((float*)mem + 2);
	return ret;
}

inline void Int4::Store3(void* mem, const Int4& i)
{
	memcpy(mem, i.vi, sizeof(float) * 3);
	// This code causes bugs in asmjs
	// *((float*)mem + 0) = i.vi[0];
	// *((float*)mem + 1) = i.vi[1];
	// *((float*)mem + 2) = i.vi[2];
}

inline Int4 Int4::Load4(const void* mem)
{
	Int4 ret;
	memcpy(ret.vi, mem, sizeof(float) * 4);
	// This code causes bugs in emscripten
	// ret.vi[0] = *((float*)mem + 0);
	// ret.vi[1] = *((float*)mem + 1);
	// ret.vi[2] = *((float*)mem + 2);
	// ret.vi[3] = *((float*)mem + 3);
	return ret;
}

inline void Int4::Store4(void* mem, const Int4& i)
{
	memcpy(mem, i.vi, sizeof(float) * 4);
	// This code causes bugs in asmjs
	// *((float*)mem + 0) = i.vi[0];
	// *((float*)mem + 1) = i.vi[1];
	// *((float*)mem + 2) = i.vi[2];
	// *((float*)mem + 3) = i.vi[3];
}

inline Int4 Int4::SetZero()
{
	Int4 ret;
	ret.vi[0] = 0;
	ret.vi[1] = 0;
	ret.vi[2] = 0;
	ret.vi[3] = 0;
	return ret;
}

inline Int4 Int4::Abs(const Int4& in)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = std::abs(in.vi[i]);
	}
	return ret;
}

inline Int4 Int4::Min(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = (lhs.vi[i] < rhs.vi[i]) ? lhs.vi[i] : rhs.vi[i];
	}
	return ret;
}

inline Int4 Int4::Max(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = (lhs.vi[i] > rhs.vi[i]) ? lhs.vi[i] : rhs.vi[i];
	}
	return ret;
}

inline Int4 Int4::MulAdd(const Int4& a, const Int4& b, const Int4& c)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = a.vi[i] + b.vi[i] * c.vi[i];
}
	return ret;
}

inline Int4 Int4::MulSub(const Int4& a, const Int4& b, const Int4& c)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = a.vi[i] - b.vi[i] * c.vi[i];
}
	return ret;
}

template<size_t LANE>
Int4 Int4::MulLane(const Int4& lhs, const Int4& rhs)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return lhs * rhs.vi[LANE];
}

template<size_t LANE>
Int4 Int4::MulAddLane(const Int4& a, const Int4& b, const Int4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return a + b * c.vi[LANE];
}

template<size_t LANE>
Int4 Int4::MulSubLane(const Int4& a, const Int4& b, const Int4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return a - b * c.vi[LANE];
}

template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
Int4 Int4::Swizzle(const Int4& in)
{
	static_assert(indexX < 4, "indexX is must be less than 4.");
	static_assert(indexY < 4, "indexY is must be less than 4.");
	static_assert(indexZ < 4, "indexZ is must be less than 4.");
	static_assert(indexW < 4, "indexW is must be less than 4.");
	return Int4{in.vi[indexX], in.vi[indexY], in.vi[indexZ], in.vi[indexW]};
}

template <int COUNT>
inline Int4 Int4::ShiftL(const Int4& lhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] << COUNT;
	}
	return ret;
}

template <int COUNT>
inline Int4 Int4::ShiftR(const Int4& lhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = lhs.vu[i] >> COUNT;
	}
	return ret;
}

template <int COUNT>
inline Int4 Int4::ShiftRA(const Int4& lhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vi[i] = lhs.vi[i] >> COUNT;
	}
	return ret;
}

template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
Int4 Int4::Mask()
{
	static_assert(X >= 2, "indexX is must be set 0 or 1.");
	static_assert(Y >= 2, "indexY is must be set 0 or 1.");
	static_assert(Z >= 2, "indexZ is must be set 0 or 1.");
	static_assert(W >= 2, "indexW is must be set 0 or 1.");
	Int4 ret;
	ret.vu[0] = 0xffffffff * X;
	ret.vu[1] = 0xffffffff * Y;
	ret.vu[2] = 0xffffffff * Z;
	ret.vu[3] = 0xffffffff * W;
	return ret;
}

inline uint32_t Int4::MoveMask(const Int4& in)
{
	return (in.vu[0] & 0x1) | (in.vu[1] & 0x2) | (in.vu[2] & 0x4) | (in.vu[3] & 0x8);
}

inline Int4 Int4::Equal(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vi[i] == rhs.vi[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::NotEqual(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vi[i] != rhs.vi[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::LessThan(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vi[i] < rhs.vi[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::LessEqual(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vi[i] <= rhs.vi[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::GreaterThan(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vi[i] > rhs.vi[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::GreaterEqual(const Int4& lhs, const Int4& rhs)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (lhs.vi[i] >= rhs.vi[i]) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::NearEqual(const Int4& lhs, const Int4& rhs, float epsilon)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (std::abs(lhs.vi[i] - rhs.vi[i]) <= epsilon) ? 0xffffffff : 0;
	}
	return ret;
}

inline Int4 Int4::IsZero(const Int4& in, float epsilon)
{
	Int4 ret;
	for (size_t i = 0; i < 4; i++)
	{
		ret.vu[i] = (std::abs(in.vi[i]) <= epsilon) ? 0xffffffff : 0;
	}
	return ret;
}

inline void Int4::Transpose(Int4& s0, Int4& s1, Int4& s2, Int4& s3)
{
	std::swap(s0.vi[1], s1.vi[0]);
	std::swap(s0.vi[2], s2.vi[0]);
	std::swap(s0.vi[3], s3.vi[0]);
	std::swap(s1.vi[2], s2.vi[1]);
	std::swap(s2.vi[3], s3.vi[2]);
	std::swap(s1.vi[3], s3.vi[1]);
}

} // namespace SIMD

} // namespace Effekseer

#endif

#endif // __EFFEKSEER_SIMD_INT4_GEN_H__

#ifndef __EFFEKSEER_SIMD_INT4_NEON_H__
#define __EFFEKSEER_SIMD_INT4_NEON_H__


#if defined(EFK_SIMD_NEON)

namespace Effekseer
{
	
namespace SIMD
{

struct Float4;

/**
 @brief    simd class for sse
 */

struct alignas(16) Int4
{
	int32x4_t s;
	
	Int4() = default;
	Int4(const Int4& rhs) = default;
	Int4(int32x4_t rhs) { s = rhs; }
	Int4(int32_t x, int32_t y, int32_t z, int32_t w) { const int32_t v[4] = {x, y, z, w}; s = vld1q_s32(v); }
	Int4(int32_t i) { s = vdupq_n_s32(i); }
	
	int32_t GetX() const { return vgetq_lane_s32(s, 0); }
	int32_t GetY() const { return vgetq_lane_s32(s, 1); }
	int32_t GetZ() const { return vgetq_lane_s32(s, 2); }
	int32_t GetW() const { return vgetq_lane_s32(s, 3); }
	
	void SetX(int32_t i) { s = vsetq_lane_s32(i, s, 0); }
	void SetY(int32_t i) { s = vsetq_lane_s32(i, s, 1); }
	void SetZ(int32_t i) { s = vsetq_lane_s32(i, s, 2); }
	void SetW(int32_t i) { s = vsetq_lane_s32(i, s, 3); }
	
	Float4 Convert4f() const;
	Float4 Cast4f() const;
	
	Int4& operator+=(const Int4& rhs);
	Int4& operator-=(const Int4& rhs);
	Int4& operator*=(const Int4& rhs);
	Int4& operator*=(int32_t rhs);
	Int4& operator/=(const Int4& rhs);
	Int4& operator/=(int32_t rhs);
	
	static Int4 Load2(const void* mem);
	static void Store2(void* mem, const Int4& i);
	static Int4 Load3(const void* mem);
	static void Store3(void* mem, const Int4& i);
	static Int4 Load4(const void* mem);
	static void Store4(void* mem, const Int4& i);
	
	static Int4 SetZero();
	static Int4 Abs(const Int4& in);
	static Int4 Min(const Int4& lhs, const Int4& rhs);
	static Int4 Max(const Int4& lhs, const Int4& rhs);
	static Int4 MulAdd(const Int4& a, const Int4& b, const Int4& c);
	static Int4 MulSub(const Int4& a, const Int4& b, const Int4& c);
	
	template<size_t LANE>
	static Int4 MulLane(const Int4& lhs, const Int4& rhs);
	template<size_t LANE>
	static Int4 MulAddLane(const Int4& a, const Int4& b, const Int4& c);
	template<size_t LANE>
	static Int4 MulSubLane(const Int4& a, const Int4& b, const Int4& c);
	template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
	static Int4 Swizzle(const Int4& v);
	
	template <int COUNT>
	static Int4 ShiftL(const Int4& in);
	template <int COUNT>
	static Int4 ShiftR(const Int4& in);
	template <int COUNT>
	static Int4 ShiftRA(const Int4& in);
	
	template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
	static Int4 Mask();
	static uint32_t MoveMask(const Int4& in);
	static Int4 Equal(const Int4& lhs, const Int4& rhs);
	static Int4 NotEqual(const Int4& lhs, const Int4& rhs);
	static Int4 LessThan(const Int4& lhs, const Int4& rhs);
	static Int4 LessEqual(const Int4& lhs, const Int4& rhs);
	static Int4 GreaterThan(const Int4& lhs, const Int4& rhs);
	static Int4 GreaterEqual(const Int4& lhs, const Int4& rhs);
	static Int4 NearEqual(const Int4& lhs, const Int4& rhs, int32_t epsilon = DefaultEpsilon);
	static Int4 IsZero(const Int4& in, int32_t epsilon = DefaultEpsilon);
	static void Transpose(Int4& s0, Int4& s1, Int4& s2, Int4& s3);
	
private:
	static Int4 SwizzleYZX(const Int4& in);
	static Int4 SwizzleZXY(const Int4& in);
};

inline Int4 operator+(const Int4& lhs, const Int4& rhs)
{
	return vaddq_s32(lhs.s, rhs.s);
}

inline Int4 operator-(const Int4& lhs, const Int4& rhs)
{
	return vsubq_s32(lhs.s, rhs.s);
}

inline Int4 operator*(const Int4& lhs, const Int4& rhs)
{
	return vmulq_s32(lhs.s, rhs.s);
}

inline Int4 operator*(const Int4& lhs, int32_t rhs)
{
	return vmulq_n_s32(lhs.s, rhs);
}

inline Int4 operator/(const Int4& lhs, const Int4& rhs)
{
#if defined(EFK_NEON_ARM64)
	return vdivq_s32(lhs.s, rhs.s);
#else
	return Int4(
		lhs.GetX() / rhs.GetX(),
		lhs.GetY() / rhs.GetY(),
		lhs.GetZ() / rhs.GetZ(),
		lhs.GetW() / rhs.GetW());
#endif
}

inline Int4 operator/(const Int4& lhs, int32_t rhs)
{
	return lhs * (1.0f / rhs);
}

inline Int4 operator&(const Int4& lhs, const Int4& rhs)
{
	uint32x4_t lhsi = vreinterpretq_u32_s32(lhs.s);
	uint32x4_t rhsi = vreinterpretq_u32_s32(rhs.s);
	return vreinterpretq_s32_u32(vandq_u32(lhsi, rhsi));
}

inline Int4 operator|(const Int4& lhs, const Int4& rhs)
{
	uint32x4_t lhsi = vreinterpretq_u32_s32(lhs.s);
	uint32x4_t rhsi = vreinterpretq_u32_s32(rhs.s);
	return vreinterpretq_s32_u32(vorrq_u32(lhsi, rhsi));
}

inline bool operator==(const Int4& lhs, const Int4& rhs)
{
	return Int4::MoveMask(Int4::Equal(lhs, rhs)) == 0xf;
}

inline bool operator!=(const Int4& lhs, const Int4& rhs)
{
	return Int4::MoveMask(Int4::Equal(lhs, rhs)) != 0xf;
}

inline Int4& Int4::operator+=(const Int4& rhs) { return *this = *this + rhs; }
inline Int4& Int4::operator-=(const Int4& rhs) { return *this = *this - rhs; }
inline Int4& Int4::operator*=(const Int4& rhs) { return *this = *this * rhs; }
inline Int4& Int4::operator*=(int32_t rhs) { return *this = *this * rhs; }
inline Int4& Int4::operator/=(const Int4& rhs) { return *this = *this / rhs; }
inline Int4& Int4::operator/=(int32_t rhs) { return *this = *this / rhs; }

inline Int4 Int4::Load2(const void* mem)
{
	int32x2_t low = vld1_s32((const int32_t*)mem);
	int32x2_t high = vdup_n_s32(0.0f);
	return vcombine_s32(low, high);
}

inline void Int4::Store2(void* mem, const Int4& i)
{
	vst1_s32((int32_t*)mem, vget_low_s32(i.s));
}

inline Int4 Int4::Load3(const void* mem)
{
	int32x2_t low = vld1_s32((const int32_t*)mem);
	int32x2_t high = vld1_lane_s32((const int32_t*)mem + 2, vdup_n_s32(0.0f), 0);
	return vcombine_s32(low, high);
}

inline void Int4::Store3(void* mem, const Int4& i)
{
	vst1_s32((int32_t*)mem, vget_low_s32(i.s));
	vst1q_lane_s32((int32_t*)mem + 2, i.s, 2);
}

inline Int4 Int4::Load4(const void* mem)
{
	return vld1q_s32((const int32_t*)mem);
}

inline void Int4::Store4(void* mem, const Int4& i)
{
	vst1q_s32((int32_t*)mem, i.s);
}

inline Int4 Int4::SetZero()
{
	return vdupq_n_s32(0.0f);
}

inline Int4 Int4::Abs(const Int4& in)
{
	return vabsq_s32(in.s);
}

inline Int4 Int4::Min(const Int4& lhs, const Int4& rhs)
{
	return vminq_s32(lhs.s, rhs.s);
}

inline Int4 Int4::Max(const Int4& lhs, const Int4& rhs)
{
	return vmaxq_s32(lhs.s, rhs.s);
}

inline Int4 Int4::MulAdd(const Int4& a, const Int4& b, const Int4& c)
{
	return vmlaq_s32(a.s, b.s, c.s);
}

inline Int4 Int4::MulSub(const Int4& a, const Int4& b, const Int4& c)
{
	return vmlsq_s32(a.s, b.s, c.s);
}

template<size_t LANE>
inline Int4 Int4::MulLane(const Int4& lhs, const Int4& rhs)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	int32x2_t rhs2 = (LANE < 2) ? vget_low_s32(rhs.s) : vget_high_s32(rhs.s);
	return vmulq_lane_s32(lhs.s, rhs2, LANE & 1);
}

template<size_t LANE>
inline Int4 Int4::MulAddLane(const Int4& a, const Int4& b, const Int4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	int32x2_t c2 = (LANE < 2) ? vget_low_s32(c.s) : vget_high_s32(c.s);
	return vmlaq_lane_s32(a.s, b.s, c2, LANE & 1);
}

template<size_t LANE>
inline Int4 Int4::MulSubLane(const Int4& a, const Int4& b, const Int4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	int32x2_t c2 = (LANE < 2) ? vget_low_s32(c.s) : vget_high_s32(c.s);
	return vmlsq_lane_s32(a.s, b.s, c2, LANE & 1);
}

//template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
//inline Int4 Int4::Swizzle(const Int4& v)
//{
//	static_assert(indexX < 4, "indexX is must be less than 4.");
//	static_assert(indexY < 4, "indexY is must be less than 4.");
//	static_assert(indexZ < 4, "indexZ is must be less than 4.");
//	static_assert(indexW < 4, "indexW is must be less than 4.");
//}

template <int COUNT>
inline Int4 Int4::ShiftL(const Int4& lhs)
{
	return vreinterpretq_s32_u32(vshlq_n_u32(vreinterpretq_u32_s32(lhs.s), COUNT));
}

template <int COUNT>
inline Int4 Int4::ShiftR(const Int4& lhs)
{
	return vreinterpretq_s32_u32(vshrq_n_u32(vreinterpretq_u32_s32(lhs.s), COUNT));
}

template <int COUNT>
inline Int4 Int4::ShiftRA(const Int4& lhs)
{
	return vshrq_n_s32(lhs.s, COUNT);
}

template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
inline Int4 Int4::Mask()
{
	static_assert(X >= 2, "indexX is must be set 0 or 1.");
	static_assert(Y >= 2, "indexY is must be set 0 or 1.");
	static_assert(Z >= 2, "indexZ is must be set 0 or 1.");
	static_assert(W >= 2, "indexW is must be set 0 or 1.");
	const uint32_t in[4] = {0xffffffff * X, 0xffffffff * Y, 0xffffffff * Z, 0xffffffff * W};
	return vld1q_u32(in);
}

inline uint32_t Int4::MoveMask(const Int4& in)
{
	uint16x4_t u16x4 = vmovn_u32(vreinterpretq_u32_s32(in.s));
	uint16_t u16[4];
	vst1_u16(u16, u16x4);
	return (u16[0] & 1) | (u16[1] & 2) | (u16[2] & 4) | (u16[3] & 8);
}

inline Int4 Int4::Equal(const Int4& lhs, const Int4& rhs)
{
	return vreinterpretq_s32_u32(vceqq_s32(lhs.s, rhs.s));
}

inline Int4 Int4::NotEqual(const Int4& lhs, const Int4& rhs)
{
	return vreinterpretq_s32_u32(vmvnq_u32(vceqq_s32(lhs.s, rhs.s)));
}

inline Int4 Int4::LessThan(const Int4& lhs, const Int4& rhs)
{
	return vreinterpretq_s32_u32(vcltq_s32(lhs.s, rhs.s));
}

inline Int4 Int4::LessEqual(const Int4& lhs, const Int4& rhs)
{
	return vreinterpretq_s32_u32(vcleq_s32(lhs.s, rhs.s));
}

inline Int4 Int4::GreaterThan(const Int4& lhs, const Int4& rhs)
{
	return vreinterpretq_s32_u32(vcgtq_s32(lhs.s, rhs.s));
}

inline Int4 Int4::GreaterEqual(const Int4& lhs, const Int4& rhs)
{
	return vreinterpretq_s32_u32(vcgeq_s32(lhs.s, rhs.s));
}

inline Int4 Int4::NearEqual(const Int4& lhs, const Int4& rhs, int32_t epsilon)
{
	return LessEqual(Abs(lhs - rhs), Int4(epsilon));
}

inline Int4 Int4::IsZero(const Int4& in, int32_t epsilon)
{
	return LessEqual(Abs(in), Int4(epsilon));
}

inline void Int4::Transpose(Int4& s0, Int4& s1, Int4& s2, Int4& s3)
{
	int32x4x2_t t0 = vzipq_s32(s0.s, s2.s);
	int32x4x2_t t1 = vzipq_s32(s1.s, s3.s);
	int32x4x2_t t2 = vzipq_s32(t0.val[0], t1.val[0]);
	int32x4x2_t t3 = vzipq_s32(t0.val[1], t1.val[1]);
	
	s0 = t2.val[0];
	s1 = t2.val[1];
	s2 = t3.val[0];
	s3 = t3.val[1];
}

inline Int4 Int4::SwizzleYZX(const Int4& in)
{
	int32x4_t ex = vextq_s32(in.s, in.s, 1);
	return vsetq_lane_s32(vgetq_lane_s32(ex, 3), ex, 2);
}

inline Int4 Int4::SwizzleZXY(const Int4& in)
{
	int32x4_t ex = vextq_s32(in.s, in.s, 3);
	return vsetq_lane_s32(vgetq_lane_s32(ex, 3), ex, 0);
}

} // namespace SIMD

} // namespace Effekseer

#endif
#endif // __EFFEKSEER_SIMD_INT4_NEON_H__

#ifndef __EFFEKSEER_SIMD_INT4_SSE_H__
#define __EFFEKSEER_SIMD_INT4_SSE_H__


#if defined(EFK_SIMD_SSE2)

namespace Effekseer
{
	
namespace SIMD
{

struct Float4;

/**
	@brief	simd class for sse
*/

struct alignas(16) Int4
{
	__m128i s;

	Int4() = default;
	Int4(const Int4& rhs) = default;
	Int4(__m128i rhs) { s = rhs; }
	Int4(__m128 rhs) { s = _mm_castps_si128(rhs); }
	Int4(int32_t x, int32_t y, int32_t z, int32_t w) { s = _mm_setr_epi32((int)x, (int)y, (int)z, (int)w); }
	Int4(int32_t i) { s = _mm_set1_epi32((int)i); }

	int32_t GetX() const { return _mm_cvtsi128_si32(s); }
	int32_t GetY() const { return _mm_cvtsi128_si32(Swizzle<1,1,1,1>(s).s); }
	int32_t GetZ() const { return _mm_cvtsi128_si32(Swizzle<2,2,2,2>(s).s); }
	int32_t GetW() const { return _mm_cvtsi128_si32(Swizzle<3,3,3,3>(s).s); }

	void SetX(int32_t i) { s = _mm_castps_si128(_mm_move_ss(_mm_castsi128_ps(s), _mm_castsi128_ps(_mm_cvtsi32_si128(i)))); }
	void SetY(int32_t i) { s = Swizzle<1,0,2,3>(_mm_castps_si128(_mm_move_ss(_mm_castsi128_ps(Swizzle<1,0,2,3>(s).s), _mm_castsi128_ps(_mm_cvtsi32_si128(i))))).s; }
	void SetZ(int32_t i) { s = Swizzle<2,1,0,3>(_mm_castps_si128(_mm_move_ss(_mm_castsi128_ps(Swizzle<2,1,0,3>(s).s), _mm_castsi128_ps(_mm_cvtsi32_si128(i))))).s; }
	void SetW(int32_t i) { s = Swizzle<3,1,2,0>(_mm_castps_si128(_mm_move_ss(_mm_castsi128_ps(Swizzle<3,1,2,0>(s).s), _mm_castsi128_ps(_mm_cvtsi32_si128(i))))).s; }

	Float4 Convert4f() const;
	Float4 Cast4f() const;

	Int4& operator+=(const Int4& rhs);
	Int4& operator-=(const Int4& rhs);
	Int4& operator*=(const Int4& rhs);
	Int4& operator*=(int32_t rhs);
	Int4& operator/=(const Int4& rhs);
	Int4& operator/=(int32_t rhs);

	static Int4 Load2(const void* mem);
	static void Store2(void* mem, const Int4& i);
	static Int4 Load3(const void* mem);
	static void Store3(void* mem, const Int4& i);
	static Int4 Load4(const void* mem);
	static void Store4(void* mem, const Int4& i);

	static Int4 SetZero();
	static Int4 Abs(const Int4& in);
	static Int4 Min(const Int4& lhs, const Int4& rhs);
	static Int4 Max(const Int4& lhs, const Int4& rhs);
	static Int4 MulAdd(const Int4& a, const Int4& b, const Int4& c);
	static Int4 MulSub(const Int4& a, const Int4& b, const Int4& c);

	template<size_t LANE>
	static Int4 MulLane(const Int4& lhs, const Int4& rhs);
	template<size_t LANE>
	static Int4 MulAddLane(const Int4& a, const Int4& b, const Int4& c);
	template<size_t LANE>
	static Int4 MulSubLane(const Int4& a, const Int4& b, const Int4& c);
	template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
	static Int4 Swizzle(const Int4& v);

	template <int COUNT>
	static Int4 ShiftL(const Int4& in);
	template <int COUNT>
	static Int4 ShiftR(const Int4& in);
	template <int COUNT>
	static Int4 ShiftRA(const Int4& in);

	template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
	static Int4 Mask();
	static uint32_t MoveMask(const Int4& in);
	static Int4 Equal(const Int4& lhs, const Int4& rhs);
	static Int4 NotEqual(const Int4& lhs, const Int4& rhs);
	static Int4 LessThan(const Int4& lhs, const Int4& rhs);
	static Int4 LessEqual(const Int4& lhs, const Int4& rhs);
	static Int4 GreaterThan(const Int4& lhs, const Int4& rhs);
	static Int4 GreaterEqual(const Int4& lhs, const Int4& rhs);
};

inline Int4 operator+(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_add_epi32(lhs.s, rhs.s)};
}

inline Int4 operator-(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_sub_epi32(lhs.s, rhs.s)};
}

inline Int4 operator*(const Int4& lhs, const Int4& rhs)
{
#if defined(EFK_SIMD_SSE4_1)
	return _mm_mullo_epi32(lhs.s, rhs.s);
#else
	__m128i tmp1 = _mm_mul_epu32(lhs.s, rhs.s);
	__m128i tmp2 = _mm_mul_epu32(_mm_srli_si128(lhs.s, 4), _mm_srli_si128(rhs.s, 4));
	return _mm_unpacklo_epi32(
		_mm_shuffle_epi32(tmp1, _MM_SHUFFLE(0,0,2,0)),
		_mm_shuffle_epi32(tmp2, _MM_SHUFFLE(0,0,2,0)));
#endif
}

inline Int4 operator*(const Int4& lhs, int32_t rhs)
{
#if defined(EFK_SIMD_SSE4_1)
	return _mm_mullo_epi32(lhs.s, _mm_set1_epi32(rhs));
#else
	__m128i tmp1 = _mm_mul_epu32(lhs.s, _mm_set1_epi32(rhs));
	__m128i tmp2 = _mm_mul_epu32(_mm_srli_si128(lhs.s, 4), _mm_set1_epi32(rhs));
	return _mm_unpacklo_epi32(
		_mm_shuffle_epi32(tmp1, _MM_SHUFFLE(0,0,2,0)),
		_mm_shuffle_epi32(tmp2, _MM_SHUFFLE(0,0,2,0)));
#endif
}

inline Int4 operator/(const Int4& lhs, const Int4& rhs)
{
	return Int4(
		lhs.GetX() * rhs.GetX(),
		lhs.GetY() * rhs.GetY(),
		lhs.GetZ() * rhs.GetZ(),
		lhs.GetW() * rhs.GetW());
}

inline Int4 operator/(const Int4& lhs, int32_t rhs)
{
	return Int4(
		lhs.GetX() * rhs,
		lhs.GetY() * rhs,
		lhs.GetZ() * rhs,
		lhs.GetW() * rhs);
}

inline Int4 operator&(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_and_si128(lhs.s, rhs.s)};
}

inline Int4 operator|(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_or_si128(lhs.s, rhs.s)};
}

inline Int4 operator^(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_xor_si128(lhs.s, rhs.s)};
}

inline bool operator==(const Int4& lhs, const Int4& rhs)
{
	return Int4::MoveMask(Int4::Equal(lhs, rhs)) == 0xf;
}

inline bool operator!=(const Int4& lhs, const Int4& rhs)
{
	return Int4::MoveMask(Int4::Equal(lhs, rhs)) != 0xf;
}

inline Int4& Int4::operator+=(const Int4& rhs) { return *this = *this + rhs; }
inline Int4& Int4::operator-=(const Int4& rhs) { return *this = *this - rhs; }
inline Int4& Int4::operator*=(const Int4& rhs) { return *this = *this * rhs; }
inline Int4& Int4::operator*=(int32_t rhs) { return *this = *this * rhs; }
inline Int4& Int4::operator/=(const Int4& rhs) { return *this = *this / rhs; }
inline Int4& Int4::operator/=(int32_t rhs) { return *this = *this / rhs; }

inline Int4 Int4::Load2(const void* mem)
{
	__m128 x = _mm_load_ss((const float*)mem + 0);
	__m128 y = _mm_load_ss((const float*)mem + 1);
	return _mm_castps_si128(_mm_unpacklo_ps(x, y));
}

inline void Int4::Store2(void* mem, const Int4& i)
{
	Int4 t1 = Swizzle<1,1,1,1>(i);
	_mm_store_ss((float*)mem + 0, _mm_castsi128_ps(i.s));
	_mm_store_ss((float*)mem + 1, _mm_castsi128_ps(t1.s));
}

inline Int4 Int4::Load3(const void* mem)
{
	__m128 x = _mm_load_ss((const float*)mem + 0);
	__m128 y = _mm_load_ss((const float*)mem + 1);
	__m128 z = _mm_load_ss((const float*)mem + 2);
	__m128 xy = _mm_unpacklo_ps(x, y);
	return _mm_castps_si128(_mm_movelh_ps(xy, z));
}

inline void Int4::Store3(void* mem, const Int4& i)
{
	Int4 t1 = Swizzle<1,1,1,1>(i);
	Int4 t2 = Swizzle<2,2,2,2>(i);
	_mm_store_ss((float*)mem + 0, _mm_castsi128_ps(i.s));
	_mm_store_ss((float*)mem + 1, _mm_castsi128_ps(t1.s));
	_mm_store_ss((float*)mem + 2, _mm_castsi128_ps(t2.s));
}

inline Int4 Int4::Load4(const void* mem)
{
	return _mm_loadu_si128((const __m128i*)mem);
}

inline void Int4::Store4(void* mem, const Int4& i)
{
	_mm_storeu_si128((__m128i*)mem, i.s);
}

inline Int4 Int4::SetZero()
{
	return _mm_setzero_si128();
}

inline Int4 Int4::Abs(const Int4& in)
{
#if defined(EFK_SIMD_SSSE3)
	return _mm_abs_epi32(in.s);
#else
	__m128i sign = _mm_srai_epi32(in.s, 31);
	return _mm_sub_epi32(_mm_xor_si128(in.s, sign), sign);
#endif
}

inline Int4 Int4::Min(const Int4& lhs, const Int4& rhs)
{
#if defined(EFK_SIMD_SSE4_1)
	return _mm_min_epi32(lhs.s, rhs.s);
#else
	__m128i mask = _mm_cmplt_epi32(lhs.s, rhs.s);
	return _mm_or_si128(_mm_and_si128(mask, lhs.s), _mm_andnot_si128(mask, rhs.s));
#endif
}

inline Int4 Int4::Max(const Int4& lhs, const Int4& rhs)
{
#if defined(EFK_SIMD_SSE4_1)
	return _mm_max_epi32(lhs.s, rhs.s);
#else
	__m128i mask = _mm_cmpgt_epi32(lhs.s, rhs.s);
	return _mm_or_si128(_mm_and_si128(mask, lhs.s), _mm_andnot_si128(mask, rhs.s));
#endif
}

inline Int4 Int4::MulAdd(const Int4& a, const Int4& b, const Int4& c)
{
	return a + b * c;
}

inline Int4 Int4::MulSub(const Int4& a, const Int4& b, const Int4& c)
{
	return a - b * c;
}

template<size_t LANE>
Int4 Int4::MulLane(const Int4& lhs, const Int4& rhs)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return lhs * Int4::Swizzle<LANE,LANE,LANE,LANE>(rhs);
}

template<size_t LANE>
Int4 Int4::MulAddLane(const Int4& a, const Int4& b, const Int4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return a + b * Int4::Swizzle<LANE,LANE,LANE,LANE>(c);
}

template<size_t LANE>
Int4 Int4::MulSubLane(const Int4& a, const Int4& b, const Int4& c)
{
	static_assert(LANE < 4, "LANE is must be less than 4.");
	return a - b * Int4::Swizzle<LANE,LANE,LANE,LANE>(c);
}

template <uint32_t indexX, uint32_t indexY, uint32_t indexZ, uint32_t indexW>
Int4 Int4::Swizzle(const Int4& v)
{
	static_assert(indexX < 4, "indexX is must be less than 4.");
	static_assert(indexY < 4, "indexY is must be less than 4.");
	static_assert(indexZ < 4, "indexZ is must be less than 4.");
	static_assert(indexW < 4, "indexW is must be less than 4.");
	return Int4{_mm_shuffle_epi32(v.s, _MM_SHUFFLE(indexW, indexZ, indexY, indexX))};
}

template <int COUNT>
inline Int4 Int4::ShiftL(const Int4& lhs)
{
	return _mm_slli_epi32(lhs.s, COUNT);
}

template <int COUNT>
inline Int4 Int4::ShiftR(const Int4& lhs)
{
	return _mm_srli_epi32(lhs.s, COUNT);
}

template <int COUNT>
inline Int4 Int4::ShiftRA(const Int4& lhs)
{
	return _mm_srai_epi32(lhs.s, COUNT);
}

template <uint32_t X, uint32_t Y, uint32_t Z, uint32_t W>
inline Int4 Int4::Mask()
{
	static_assert(X >= 2, "indexX is must be set 0 or 1.");
	static_assert(Y >= 2, "indexY is must be set 0 or 1.");
	static_assert(Z >= 2, "indexZ is must be set 0 or 1.");
	static_assert(W >= 2, "indexW is must be set 0 or 1.");
	return _mm_setr_epi32(
		(int)(0xffffffff * X), 
		(int)(0xffffffff * Y), 
		(int)(0xffffffff * Z), 
		(int)(0xffffffff * W));
}

inline uint32_t Int4::MoveMask(const Int4& in)
{
	return (uint32_t)_mm_movemask_ps(_mm_castsi128_ps(in.s));
}

inline Int4 Int4::Equal(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_cmpeq_epi32(lhs.s, rhs.s)};
}

inline Int4 Int4::NotEqual(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_andnot_si128(_mm_cmpeq_epi32(lhs.s, rhs.s), _mm_set1_epi32(-1))};
}

inline Int4 Int4::LessThan(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_cmplt_epi32(lhs.s, rhs.s)};
}

inline Int4 Int4::LessEqual(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_andnot_si128(_mm_cmpgt_epi32(lhs.s, rhs.s), _mm_set1_epi32(-1))};
}

inline Int4 Int4::GreaterThan(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_cmpgt_epi32(lhs.s, rhs.s)};
}

inline Int4 Int4::GreaterEqual(const Int4& lhs, const Int4& rhs)
{
	return Int4{_mm_andnot_si128(_mm_cmplt_epi32(lhs.s, rhs.s), _mm_set1_epi32(-1))};
}

} // namespace SIMD

} // namespace Effekseer

#endif

#endif // __EFFEKSEER_SIMD_INT4_SSE_H__

#ifndef __EFFEKSEER_SIMD_BRIDGE_GEN_H__
#define __EFFEKSEER_SIMD_BRIDGE_GEN_H__


#if defined(EFK_SIMD_GEN)

namespace Effekseer
{
	
namespace SIMD
{

inline Int4 Float4::Convert4i() const { return Int4((int32_t)vf[0], (int32_t)vf[1], (int32_t)vf[2], (int32_t)vf[3]); }

inline Int4 Float4::Cast4i() const { return Int4(vu[0], vu[1], vu[2], vu[3]); }

inline Float4 Int4::Convert4f() const { return Float4((float)vi[0], (float)vi[1], (float)vi[2], (float)vi[3]); }

inline Float4 Int4::Cast4f() const { return Float4(vf[0], vf[1], vf[2], vf[3]); }

} // namespace SIMD

} // namespace Effekseer

#endif

#endif // __EFFEKSEER_SIMD_BRIDGE_GEN_H__

#ifndef __EFFEKSEER_SIMD_BRIDGE_NEON_H__
#define __EFFEKSEER_SIMD_BRIDGE_NEON_H__


#if defined(EFK_SIMD_NEON)

namespace Effekseer
{
	
namespace SIMD
{

inline Int4 Float4::Convert4i() const { return vcvtq_s32_f32(s); }

inline Int4 Float4::Cast4i() const { return vreinterpretq_s32_f32(s); }

inline Float4 Int4::Convert4f() const { return vcvtq_f32_s32(s); }

inline Float4 Int4::Cast4f() const { return vreinterpretq_f32_s32(s); }

} // namespace SIMD

} // namespace Effekseer

#endif
#endif // __EFFEKSEER_SIMD_BRIDGE_NEON_H__

#ifndef __EFFEKSEER_SIMD_BRIDGE_SSE_H__
#define __EFFEKSEER_SIMD_BRIDGE_SSE_H__


#if defined(EFK_SIMD_SSE2)

namespace Effekseer
{
	
namespace SIMD
{

inline Int4 Float4::Convert4i() const { return _mm_cvtps_epi32(s); }

inline Int4 Float4::Cast4i() const { return _mm_castps_si128(s); }

inline Float4 Int4::Convert4f() const { return _mm_cvtepi32_ps(s); }

inline Float4 Int4::Cast4f() const { return _mm_castsi128_ps(s); }

} // namespace SIMD

} // namespace Effekseer

#endif

#endif // __EFFEKSEER_SIMD_BRIDGE_SSE_H__

#ifndef __EFFEKSEER_SIMD_VEC2F_H__
#define __EFFEKSEER_SIMD_VEC2F_H__


namespace Effekseer
{

struct Vector2D;
struct vector2d;

namespace SIMD
{

struct Vec2f
{
	Float4 s;

	explicit Vec2f() = default;
	Vec2f(const Vec2f& vec) = default;
	Vec2f(float x, float y): s(x, y, 0.0f, 1.0f) {}
	Vec2f(const std::array<float, 2>& v): s(v[0], v[1], 0.0f, 1.0f) {}
	Vec2f(const Float4& vec): s(vec) {}
	Vec2f(const Vector2D& vec);
	Vec2f(const vector2d& vec);

	float GetX() const { return s.GetX(); }
	float GetY() const { return s.GetY(); }

	void SetX(float o) { s.SetX(o); }
	void SetY(float o) { s.SetY(o); }

	Vec2f& operator+=(const Vec2f& o) { s += o.s; return *this; }
	Vec2f& operator-=(const Vec2f& o) { s -= o.s; return *this; }
	Vec2f& operator*=(const Vec2f& o) { s *= o.s; return *this; }
	Vec2f& operator*=(float o) { s *= o; return *this; }
	Vec2f& operator/=(const Vec2f& o) { s /= o.s; return *this; }
	Vec2f& operator/=(float o) { s /= o; return *this; }

	float LengthSq() const;
	float Length() const;
	bool IsZero(float range = DefaultEpsilon) const;
	Vec2f Normalize() const;

	static Vec2f Load(const void* mem);
	static void Store(void* mem, const Vec2f& i);

	static Vec2f Sqrt(const Vec2f& i);
	static Vec2f Rsqrt(const Vec2f& i);
	static Vec2f Abs(const Vec2f& i);
	static Vec2f Min(const Vec2f& lhs, const Vec2f& rhs);
	static Vec2f Max(const Vec2f& lhs, const Vec2f& rhs);
	static bool Equal(const Vec2f& lhs, const Vec2f& rhs, float epsilon);
};

inline Vec2f operator+(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s + rhs.s};
}

inline Vec2f operator-(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s - rhs.s};
}

inline Vec2f operator*(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s * rhs.s};
}

inline Vec2f operator*(const Vec2f& lhs, float rhs)
{
	return Vec2f{lhs.s * rhs};
}

inline Vec2f operator/(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s / rhs.s};
}

inline Vec2f operator/(const Vec2f& lhs, float rhs)
{
	return Vec2f{lhs.s / rhs};
}

inline bool operator==(const Vec2f& lhs, const Vec2f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x03) == 0x3;
}

inline bool operator!=(const Vec2f& lhs, const Vec2f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x03) != 0x3;
}

inline Vec2f Vec2f::Load(const void* mem)
{
	return Float4::Load2(mem);
}

inline void Vec2f::Store(void* mem, const Vec2f& i)
{
	Float4::Store2(mem, i.s);
}

inline Vec2f Vec2f::Sqrt(const Vec2f& i)
{
	return Vec2f{Float4::Sqrt(i.s)};
}

inline Vec2f Vec2f::Rsqrt(const Vec2f& i)
{
	return Vec2f{Float4::Rsqrt(i.s)};
}

inline Vec2f Vec2f::Abs(const Vec2f& i)
{
	return Vec2f{Float4::Abs(i.s)};
}

inline Vec2f Vec2f::Min(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{Float4::Min(lhs.s, rhs.s)};
}

inline Vec2f Vec2f::Max(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{Float4::Max(lhs.s, rhs.s)};
}

inline bool Vec2f::Equal(const Vec2f& lhs, const Vec2f& rhs, float epsilon)
{
	return (Float4::MoveMask(Float4::NearEqual(lhs.s, rhs.s, epsilon)) & 0x3) == 0x3;
}

inline float Vec2f::LengthSq() const
{
	auto o = s * s;
	return o.GetX() + o.GetY();
}

inline float Vec2f::Length() const
{
	return Effekseer::SIMD::Sqrt(LengthSq());
}

inline bool Vec2f::IsZero(float range) const
{
	return LengthSq() < range * range;
}

inline Vec2f Vec2f::Normalize() const
{
	return *this * Effekseer::SIMD::Rsqrt(LengthSq());
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_VEC2F_H__

#ifndef __EFFEKSEER_SIMD_VEC3F_H__
#define __EFFEKSEER_SIMD_VEC3F_H__

#include <functional>

namespace Effekseer
{

struct Vector3D;
struct vector3d;

namespace SIMD
{

struct Mat43f;
struct Mat44f;

struct Vec3f
{
	Float4 s;

	explicit Vec3f() = default;
	Vec3f(const Vec3f& vec) = default;
	Vec3f(float x, float y, float z)
		: s(x, y, z, 1.0f)
	{
	}
	Vec3f(const Float4& vec)
		: s(vec)
	{
	}
	Vec3f(const Vector3D& vec);
	Vec3f(const vector3d& vec);
	Vec3f(const std::array<float, 3>& vec);

	float GetX() const
	{
		return s.GetX();
	}
	float GetY() const
	{
		return s.GetY();
	}
	float GetZ() const
	{
		return s.GetZ();
	}

	void SetX(float o)
	{
		s.SetX(o);
	}
	void SetY(float o)
	{
		s.SetY(o);
	}
	void SetZ(float o)
	{
		s.SetZ(o);
	}

	Vec3f& operator+=(const Vec3f& o)
	{
		s += o.s;
		return *this;
	}
	Vec3f& operator-=(const Vec3f& o)
	{
		s -= o.s;
		return *this;
	}
	Vec3f& operator*=(const Vec3f& o)
	{
		s *= o.s;
		return *this;
	}
	Vec3f& operator*=(float o)
	{
		s *= o;
		return *this;
	}
	Vec3f& operator/=(const Vec3f& o)
	{
		s /= o.s;
		return *this;
	}
	Vec3f& operator/=(float o)
	{
		s /= o;
		return *this;
	}

	float GetSquaredLength() const;
	float GetLength() const;
	bool IsZero(float epsiron = DefaultEpsilon) const;
	Vec3f Normalize() const;
	Vec3f NormalizePrecisely() const;
	Vec3f NormalizeFast() const;

	static Vec3f Load(const void* mem);
	static void Store(void* mem, const Vec3f& i);

	static Vec3f Sqrt(const Vec3f& i);
	static Vec3f Rsqrt(const Vec3f& i);
	static Vec3f Abs(const Vec3f& i);
	static Vec3f Min(const Vec3f& lhs, const Vec3f& rhs);
	static Vec3f Max(const Vec3f& lhs, const Vec3f& rhs);
	static float Dot(const Vec3f& lhs, const Vec3f& rhs);
	static Vec3f Cross(const Vec3f& lhs, const Vec3f& rhs);
	static bool Equal(const Vec3f& lhs, const Vec3f& rhs, float epsilon = DefaultEpsilon);
	static Vec3f Transform(const Vec3f& lhs, const Mat43f& rhs);
	static Vec3f Transform(const Vec3f& lhs, const Mat44f& rhs);
};

inline Vec3f operator-(const Vec3f& i)
{
	return Vec3f(-i.GetX(), -i.GetY(), -i.GetZ());
}

inline Vec3f operator+(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s + rhs.s};
}

inline Vec3f operator-(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s - rhs.s};
}

inline Vec3f operator*(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s * rhs.s};
}

inline Vec3f operator*(const Vec3f& lhs, float rhs)
{
	return Vec3f{lhs.s * rhs};
}

inline Vec3f operator/(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s / rhs.s};
}

inline Vec3f operator/(const Vec3f& lhs, float rhs)
{
	return Vec3f{lhs.s / rhs};
}

inline bool operator==(const Vec3f& lhs, const Vec3f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x07) == 0x7;
}

inline bool operator!=(const Vec3f& lhs, const Vec3f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x07) != 0x7;
}

inline Vec3f Vec3f::Load(const void* mem)
{
	return Float4::Load3(mem);
}

inline void Vec3f::Store(void* mem, const Vec3f& i)
{
	Float4::Store3(mem, i.s);
}

inline Vec3f Vec3f::Sqrt(const Vec3f& i)
{
	return Vec3f{Float4::Sqrt(i.s)};
}

inline Vec3f Vec3f::Rsqrt(const Vec3f& i)
{
	return Vec3f{Float4::Rsqrt(i.s)};
}

inline Vec3f Vec3f::Abs(const Vec3f& i)
{
	return Vec3f{Float4::Abs(i.s)};
}

inline Vec3f Vec3f::Min(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{Float4::Min(lhs.s, rhs.s)};
}

inline Vec3f Vec3f::Max(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{Float4::Max(lhs.s, rhs.s)};
}

inline float Vec3f::Dot(const Vec3f& lhs, const Vec3f& rhs)
{
	return Float4::Dot3(lhs.s, rhs.s).GetX();
}

inline Vec3f Vec3f::Cross(const Vec3f& lhs, const Vec3f& rhs)
{
	return Float4::Cross3(lhs.s, rhs.s);
}

inline bool Vec3f::Equal(const Vec3f& lhs, const Vec3f& rhs, float epsilon)
{
	return (Float4::MoveMask(Float4::NearEqual(lhs.s, rhs.s, epsilon)) & 0x7) == 0x7;
}

inline float Vec3f::GetSquaredLength() const
{
	auto o = s * s;
	return o.GetX() + o.GetY() + o.GetZ();
}

inline float Vec3f::GetLength() const
{
	return Effekseer::SIMD::Sqrt(GetSquaredLength());
}

inline bool Vec3f::IsZero(float epsiron) const
{
	return (Float4::MoveMask(Float4::IsZero(s, epsiron)) & 0x7) == 0x7;
}

inline Vec3f Vec3f::Normalize() const
{
	return *this * Effekseer::SIMD::Rsqrt(GetSquaredLength());
}

inline Vec3f Vec3f::NormalizePrecisely() const
{
	return *this / Effekseer::SIMD::Sqrt(GetSquaredLength());
}

inline Vec3f Vec3f::NormalizeFast() const
{
	return *this * Effekseer::SIMD::Rsqrt(GetSquaredLength());
}

} // namespace SIMD

} // namespace Effekseer

namespace std
{

template <>
struct hash<Effekseer::SIMD::Vec3f>
{
	size_t operator()(const Effekseer::SIMD::Vec3f& _Keyval) const noexcept
	{
		return std::hash<float>()(_Keyval.GetX()) + std::hash<float>()(_Keyval.GetY()) + std::hash<float>()(_Keyval.GetZ());
	}
};

} // namespace std

#endif // __EFFEKSEER_SIMD_VEC3F_H__

#ifndef __EFFEKSEER_SIMD_VEC4F_H__
#define __EFFEKSEER_SIMD_VEC4F_H__


namespace Effekseer
{
	
namespace SIMD
{

struct Vec4f
{
	Float4 s;

	Vec4f() = default;
	Vec4f(const Vec4f& vec) = default;
	Vec4f(const Float4& vec): s(vec) {}

	float GetX() const { return s.GetX(); }
	float GetY() const { return s.GetY(); }
	float GetZ() const { return s.GetZ(); }
	float GetW() const { return s.GetW(); }

	void SetX(float o) { s.SetX(o); }
	void SetY(float o) { s.SetY(o); }
	void SetZ(float o) { s.SetZ(o); }
	void SetW(float o) { s.SetW(o); }

	Vec4f& operator+=(const Vec4f& o)
	{
		this->s = this->s + o.s;
		return *this;
	}

	Vec4f& operator-=(const Vec4f& o)
	{
		this->s = this->s - o.s;
		return *this;
	}

	Vec4f& operator*=(const Vec4f& o)
	{
		this->s = this->s * o.s;
		return *this;
	}

	Vec4f& operator/=(const Vec4f& o)
	{
		this->s = this->s / o.s;
		return *this;
	}

	static Vec4f Sqrt(const Vec4f& i);
	static Vec4f Rsqrt(const Vec4f& i);
	static Vec4f Abs(const Vec4f& i);
	static Vec4f Min(const Vec4f& lhs, const Vec4f& rhs);
	static Vec4f Max(const Vec4f& lhs, const Vec4f& rhs);
	static bool Equal(const Vec4f& lhs, const Vec4f& rhs, float epsilon);
	static Vec4f Transform(const Vec4f& lhs, const Mat43f& rhs);
	static Vec4f Transform(const Vec4f& lhs, const Mat44f& rhs);
};

inline Vec4f operator+(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s + rhs.s}; }

inline Vec4f operator-(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s - rhs.s}; }

inline Vec4f operator*(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s * rhs.s}; }

inline Vec4f operator/(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s / rhs.s}; }

inline bool operator==(const Vec4f& lhs, const Vec4f& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) == 0xf;
}

inline bool operator!=(const Vec4f& lhs, const Vec4f& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) != 0xf;
}

inline Vec4f Vec4f::Sqrt(const Vec4f& i)
{
	return Vec4f{Float4::Sqrt(i.s)};
}

inline Vec4f Vec4f::Rsqrt(const Vec4f& i)
{
	return Vec4f{Float4::Rsqrt(i.s)};
}

inline Vec4f Vec4f::Abs(const Vec4f& i)
{
	return Vec4f{Float4::Abs(i.s)};
}

inline Vec4f Vec4f::Min(const Vec4f& lhs, const Vec4f& rhs)
{
	return Vec4f{Float4::Min(lhs.s, rhs.s)};
}

inline Vec4f Vec4f::Max(const Vec4f& lhs, const Vec4f& rhs)
{
	return Vec4f{Float4::Max(lhs.s, rhs.s)};
}

inline bool Vec4f::Equal(const Vec4f& lhs, const Vec4f& rhs, float epsilon)
{
	return (Float4::MoveMask(Float4::NearEqual(lhs.s, rhs.s, epsilon)) & 0xf) == 0xf;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_SIMD_VEC4F_H__

#ifndef __EFFEKSEER_SIMD_MAT43F_H__
#define __EFFEKSEER_SIMD_MAT43F_H__


namespace Effekseer
{

struct Matrix43;

namespace SIMD
{

struct Mat43f
{
	Float4 X;
	Float4 Y;
	Float4 Z;

	Mat43f() = default;
	Mat43f(const Mat43f& rhs) = default;
	Mat43f(float m11, float m12, float m13,
		   float m21, float m22, float m23,
		   float m31, float m32, float m33,
		   float m41, float m42, float m43);
	Mat43f(const Matrix43& mat);

	bool IsValid() const;

	Vec3f GetScale() const;

	Mat43f GetRotation() const;

	Vec3f GetTranslation() const;

	void GetSRT(Vec3f& s, Mat43f& r, Vec3f& t) const;

	void SetTranslation(const Vec3f& t);

	Mat43f& operator*=(const Mat43f& rhs);

	Mat43f& operator*=(float rhs);

	static const Mat43f Identity;

	static bool Equal(const Mat43f& lhs, const Mat43f& rhs, float epsilon = DefaultEpsilon);

	static Mat43f SRT(const Vec3f& s, const Mat43f& r, const Vec3f& t);

	static Mat43f Scaling(float x, float y, float z);

	static Mat43f Scaling(const Vec3f& scale);

	static Mat43f RotationX(float angle);

	static Mat43f RotationY(float angle);

	static Mat43f RotationZ(float angle);

	static Mat43f RotationXYZ(float rx, float ry, float rz);

	static Mat43f RotationZXY(float rz, float rx, float ry);

	static Mat43f RotationAxis(const Vec3f& axis, float angle);

	static Mat43f RotationAxis(const Vec3f& axis, float s, float c);

	static Mat43f Translation(float x, float y, float z);

	static Mat43f Translation(const Vec3f& pos);
};

inline Mat43f::Mat43f(
	float m11, float m12, float m13,
	float m21, float m22, float m23,
	float m31, float m32, float m33,
	float m41, float m42, float m43)
	: X(m11, m21, m31, m41)
	, Y(m12, m22, m32, m42)
	, Z(m13, m23, m33, m43)
{
}

inline bool operator==(const Mat43f& lhs, const Mat43f& rhs)
{
	return lhs.X == rhs.X && lhs.Y == rhs.Y && lhs.Z == rhs.Z;
}

inline bool operator!=(const Mat43f& lhs, const Mat43f& rhs)
{
	return lhs.X != rhs.X && lhs.Y != rhs.Y && lhs.Z != rhs.Z;
}

inline Mat43f operator*(const Mat43f& lhs, const Mat43f& rhs)
{
	const Float4 mask = Float4::SetUInt(0, 0, 0, 0xffffffff);

	Mat43f res;
	res.X = mask & rhs.X;
	res.X = Float4::MulAddLane<0>(res.X, lhs.X, rhs.X);
	res.X = Float4::MulAddLane<1>(res.X, lhs.Y, rhs.X);
	res.X = Float4::MulAddLane<2>(res.X, lhs.Z, rhs.X);

	res.Y = mask & rhs.Y;
	res.Y = Float4::MulAddLane<0>(res.Y, lhs.X, rhs.Y);
	res.Y = Float4::MulAddLane<1>(res.Y, lhs.Y, rhs.Y);
	res.Y = Float4::MulAddLane<2>(res.Y, lhs.Z, rhs.Y);

	res.Z = mask & rhs.Z;
	res.Z = Float4::MulAddLane<0>(res.Z, lhs.X, rhs.Z);
	res.Z = Float4::MulAddLane<1>(res.Z, lhs.Y, rhs.Z);
	res.Z = Float4::MulAddLane<2>(res.Z, lhs.Z, rhs.Z);
	return res;
}

inline Vec3f Vec3f::Transform(const Vec3f& lhs, const Mat43f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = Float4::SetZero();
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulAddLane<0>(s3, s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	return Vec3f{res};
}

inline Vec4f Vec4f::Transform(const Vec4f& lhs, const Mat43f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = Float4(0.0f, 0.0f, 0.0f, 1.0f);
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulLane<0>(s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	res = Float4::MulAddLane<3>(res, s3, lhs.s);
	return res;
}

inline Mat43f& Mat43f::operator*=(const Mat43f& rhs)
{
	*this = *this * rhs;
	return *this;
}

inline Mat43f& Mat43f::operator*=(float rhs)
{
	X *= rhs;
	Y *= rhs;
	Z *= rhs;
	return *this;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_SIMD_MAT43F_H__

#ifndef __EFFEKSEER_SIMD_MAT44F_H__
#define __EFFEKSEER_SIMD_MAT44F_H__


namespace Effekseer
{

struct Matrix44;

namespace SIMD
{

struct Mat44f
{
	Float4 X;
	Float4 Y;
	Float4 Z;
	Float4 W;
	
	Mat44f() = default;
	Mat44f(const Mat44f& rhs) = default;
	Mat44f(float m11, float m12, float m13, float m14,
		   float m21, float m22, float m23, float m24,
		   float m31, float m32, float m33, float m34,
		   float m41, float m42, float m43, float m44);
	Mat44f(const Mat43f& mat);
	Mat44f(const Matrix44& mat);

	bool IsValid() const;

	Vec3f GetScale() const;

	Mat44f GetRotation() const;

	Vec3f GetTranslation() const;

	void GetSRT(Vec3f& s, Mat44f& r, Vec3f& t) const;

	void SetTranslation(const Vec3f& t);

	Mat44f Transpose() const;

	Mat44f& operator*=(const Mat44f& rhs);
	
	Mat44f& operator*=(float rhs);

	static const Mat44f Identity;

	static bool Equal(const Mat44f& lhs, const Mat44f& rhs, float epsilon = DefaultEpsilon);

	static Mat44f SRT(const Vec3f& s, const Mat44f& r, const Vec3f& t);

	static Mat44f Scaling(float x, float y, float z);

	static Mat44f Scaling(const Vec3f& scale);

	static Mat44f RotationX(float angle);

	static Mat44f RotationY(float angle);

	static Mat44f RotationZ(float angle);

	static Mat44f RotationXYZ(float rx, float ry, float rz);

	static Mat44f RotationZXY(float rz, float rx, float ry);

	static Mat44f RotationAxis(const Vec3f& axis, float angle);

	static Mat44f RotationAxis(const Vec3f& axis, float s, float c);

	static Mat44f Translation(float x, float y, float z);

	static Mat44f Translation(const Vec3f& pos);
};

inline Mat44f::Mat44f(
	float m11, float m12, float m13, float m14,
	float m21, float m22, float m23, float m24,
	float m31, float m32, float m33, float m34,
	float m41, float m42, float m43, float m44)
	: X(m11, m21, m31, m41)
	, Y(m12, m22, m32, m42)
	, Z(m13, m23, m33, m43)
	, W(m14, m24, m34, m44)
{
}

inline Mat44f::Mat44f(const Mat43f& mat)
	: X(mat.X)
	, Y(mat.Y)
	, Z(mat.Z)
	, W(0.0f, 0.0f, 0.0f, 1.0f)
{
}

inline bool operator==(const Mat44f& lhs, const Mat44f& rhs)
{
	return lhs.X == rhs.X && lhs.Y == rhs.Y && lhs.Z == rhs.Z && lhs.W == rhs.W;
}

inline bool operator!=(const Mat44f& lhs, const Mat44f& rhs)
{
	return lhs.X != rhs.X && lhs.Y != rhs.Y && lhs.Z != rhs.Z && lhs.W != rhs.W;
}

inline Mat44f operator*(const Mat44f& lhs, const Mat44f& rhs)
{
	Mat44f res;
	res.X = Float4::MulLane<0>(lhs.X, rhs.X);
	res.X = Float4::MulAddLane<1>(res.X, lhs.Y, rhs.X);
	res.X = Float4::MulAddLane<2>(res.X, lhs.Z, rhs.X);
	res.X = Float4::MulAddLane<3>(res.X, lhs.W, rhs.X);

	res.Y = Float4::MulLane<0>(lhs.X, rhs.Y);
	res.Y = Float4::MulAddLane<1>(res.Y, lhs.Y, rhs.Y);
	res.Y = Float4::MulAddLane<2>(res.Y, lhs.Z, rhs.Y);
	res.Y = Float4::MulAddLane<3>(res.Y, lhs.W, rhs.Y);

	res.Z = Float4::MulLane<0>(lhs.X, rhs.Z);
	res.Z = Float4::MulAddLane<1>(res.Z, lhs.Y, rhs.Z);
	res.Z = Float4::MulAddLane<2>(res.Z, lhs.Z, rhs.Z);
	res.Z = Float4::MulAddLane<3>(res.Z, lhs.W, rhs.Z);

	res.W = Float4::MulLane<0>(lhs.X, rhs.W);
	res.W = Float4::MulAddLane<1>(res.W, lhs.Y, rhs.W);
	res.W = Float4::MulAddLane<2>(res.W, lhs.Z, rhs.W);
	res.W = Float4::MulAddLane<3>(res.W, lhs.W, rhs.W);
	return res;
}

inline Vec3f Vec3f::Transform(const Vec3f& lhs, const Mat44f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = rhs.W;
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulAddLane<0>(s3, s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	return Vec3f{res};
}

inline Vec4f Vec4f::Transform(const Vec4f& lhs, const Mat44f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = rhs.W;
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulLane<0>(s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	res = Float4::MulAddLane<3>(res, s3, lhs.s);
	return res;
}

inline Mat44f& Mat44f::operator*=(const Mat44f& rhs)
{
	*this = *this * rhs;
	return *this;
}

inline Mat44f& Mat44f::operator*=(float rhs)
{
	X *= rhs;
	Y *= rhs;
	Z *= rhs;
	W *= rhs;
	return *this;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_VEC4F_H__

#ifndef __EFFEKSEER_SIMD_UTILS_H__
#define __EFFEKSEER_SIMD_UTILS_H__

#include <stdlib.h>

namespace Effekseer
{
	
namespace SIMD
{

template <size_t align>
class AlignedAllocationPolicy {
public:
	static void* operator new(size_t size) {
#if defined(__EMSCRIPTEN__) && __EMSCRIPTEN_minor__ < 38
		return malloc(size);
#elif defined(_MSC_VER)
		return _mm_malloc(size, align);
#else
		void *ptr = nullptr;
		posix_memalign(&ptr, align, size);
		return ptr;
#endif
	}
	static void operator delete(void* ptr) {
#if defined(__EMSCRIPTEN__) && __EMSCRIPTEN_minor__ < 38
		free(ptr);
#elif defined(_MSC_VER)
		_mm_free(ptr);
#else
		return free(ptr);
#endif
	}
};

inline Vector2D ToStruct(const Vec2f& o)
{
	Vector2D ret;
	Vec2f::Store(&ret, o);
	return ret;
}

inline Vector3D ToStruct(const Vec3f& o)
{
	Vector3D ret;
	Vec3f::Store(&ret, o);
	return ret;
}

inline Matrix43 ToStruct(const Mat43f& o)
{
	Float4 tx = o.X;
	Float4 ty = o.Y;
	Float4 tz = o.Z;
	Float4 tw = Float4::SetZero();
	Float4::Transpose(tx, ty, tz, tw);

	Matrix43 ret;
	Float4::Store3(ret.Value[0], tx);
	Float4::Store3(ret.Value[1], ty);
	Float4::Store3(ret.Value[2], tz);
	Float4::Store3(ret.Value[3], tw);
	return ret;
}

inline Matrix44 ToStruct(const Mat44f& o)
{
	Float4 tx = o.X;
	Float4 ty = o.Y;
	Float4 tz = o.Z;
	Float4 tw = o.W;
	Float4::Transpose(tx, ty, tz, tw);

	Matrix44 ret;
	Float4::Store4(ret.Values[0], tx);
	Float4::Store4(ret.Values[1], ty);
	Float4::Store4(ret.Values[2], tz);
	Float4::Store4(ret.Values[3], tw);
	return ret;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_SIMD_UTILS_H__
