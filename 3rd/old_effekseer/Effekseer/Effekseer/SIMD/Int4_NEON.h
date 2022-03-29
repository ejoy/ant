
#ifndef __EFFEKSEER_SIMD_INT4_NEON_H__
#define __EFFEKSEER_SIMD_INT4_NEON_H__

#include "Base.h"

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