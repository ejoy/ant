
#ifndef __EFFEKSEER_SIMD_FLOAT4_GEN_H__
#define __EFFEKSEER_SIMD_FLOAT4_GEN_H__

#include "Base.h"

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