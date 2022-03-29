
#ifndef __EFFEKSEER_SIMD_FLOAT4_SSE_H__
#define __EFFEKSEER_SIMD_FLOAT4_SSE_H__

#include "Base.h"

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