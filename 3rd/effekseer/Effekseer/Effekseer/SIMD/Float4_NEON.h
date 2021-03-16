
#ifndef __EFFEKSEER_SIMD_FLOAT4_NEON_H__
#define __EFFEKSEER_SIMD_FLOAT4_NEON_H__

#include "Base.h"

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
