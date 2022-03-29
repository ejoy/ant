
#ifndef __EFFEKSEER_SIMD_INT4_SSE_H__
#define __EFFEKSEER_SIMD_INT4_SSE_H__

#include "Base.h"

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
