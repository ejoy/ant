
#ifndef __EFFEKSEER_SIMD_INT4_GEN_H__
#define __EFFEKSEER_SIMD_INT4_GEN_H__

#include "Base.h"

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