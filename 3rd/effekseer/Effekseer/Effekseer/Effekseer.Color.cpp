

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.Color.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#if (defined(_M_IX86_FP) && _M_IX86_FP >= 2) || defined(__SSE__)
#define EFK_SSE2
#include <emmintrin.h>
#elif defined(__ARM_NEON__)
#define EFK_NEON
#include <arm_neon.h>
#endif

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Color::Color(uint8_t r, uint8_t g, uint8_t b, uint8_t a)
	: R(r)
	, G(g)
	, B(b)
	, A(a)
{
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Color Color::Mul(Color in1, Color in2)
{
#if defined(EFK_SSE2)
	__m128i s1 = _mm_cvtsi32_si128(*(int32_t*)&in1);
	__m128i s2 = _mm_cvtsi32_si128(*(int32_t*)&in2);
	__m128i zero = _mm_setzero_si128();
	__m128i mask = _mm_set1_epi16(1);

	s1 = _mm_unpacklo_epi8(s1, zero);
	s2 = _mm_unpacklo_epi8(s2, zero);

	__m128i r0 = _mm_mullo_epi16(s1, s2);
	__m128i r1 = _mm_srli_epi16(r0, 8);
	__m128i r2 = _mm_and_si128(r0, mask);
	__m128i r3 = _mm_or_si128(r2, r1);
	__m128i res = _mm_packus_epi16(r3, zero);

	Color o;
	*(int*)&o = _mm_cvtsi128_si32(res);
	return o;
#elif defined(EFK_NEON)
	uint8x8_t s1 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in1));
	uint8x8_t s2 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in2));
	uint16x8_t mask = vmovq_n_u16(1);
	uint16x8_t s3 = vmovl_u8(s1);
	uint16x8_t s4 = vmovl_u8(s2);
	uint16x8_t r0 = vmulq_u16(s3, s4);
	uint16x8_t r1 = vshrq_n_u16(r0, 8);
	uint16x8_t r2 = vandq_u16(r0, mask);
	uint16x8_t r3 = vorrq_u16(r2, r1);
	uint8x8_t res = vqmovn_u16(r3);

	Color o;
	*(uint32_t*)&o = vget_lane_u32(vreinterpret_u32_u8(res), 0);
	return o;
#else
	Color o;
	o.R = (uint8_t)((float)in1.R * (float)in2.R / 255.0f);
	o.G = (uint8_t)((float)in1.G * (float)in2.G / 255.0f);
	o.B = (uint8_t)((float)in1.B * (float)in2.B / 255.0f);
	o.A = (uint8_t)((float)in1.A * (float)in2.A / 255.0f);
	return o;
#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Color Color::Mul(Color in1, float in2)
{
#if defined(EFK_SSE2)
	__m128i s1 = _mm_cvtsi32_si128(*(int32_t*)&in1);
	__m128i s2 = _mm_set1_epi16((int16_t)(in2 * 256));
	__m128i zero = _mm_setzero_si128();

	s1 = _mm_unpacklo_epi8(s1, zero);

	__m128i res = _mm_mullo_epi16(s1, s2);
	res = _mm_srli_epi16(res, 8);
	res = _mm_packus_epi16(res, zero);

	Color o;
	*(int*)&o = _mm_cvtsi128_si32(res);
	return o;
#elif defined(EFK_NEON)
	uint8x8_t s1 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in1));
	uint16x8_t s2 = vmovq_n_u16((uint16_t)(in2 * 256));
	uint16x8_t s3 = vmovl_u8(s1);
	uint16x8_t r0 = vmulq_u16(s3, s2);
	uint16x8_t r1 = vshrq_n_u16(r0, 8);
	uint8x8_t res = vqmovn_u16(r1);

	Color o;
	*(uint32_t*)&o = vget_lane_u32(vreinterpret_u32_u8(res), 0);
	return o;
#else
	Color o;
	o.R = (uint8_t)Clamp((int)((float)in1.R * in2), 255, 0);
	o.G = (uint8_t)Clamp((int)((float)in1.G * in2), 255, 0);
	o.B = (uint8_t)Clamp((int)((float)in1.B * in2), 255, 0);
	o.A = (uint8_t)Clamp((int)((float)in1.A * in2), 255, 0);
	return o;
#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Color Color::Lerp(const Color in1, const Color in2, float t)
{
	/*
#if defined(EFK_SSE2)
	__m128i s1 = _mm_cvtsi32_si128(*(int32_t*)&in1);
	__m128i s2 = _mm_cvtsi32_si128(*(int32_t*)&in2);
	__m128i tm = _mm_set1_epi16((int16_t)(t * 256));
	__m128i zero = _mm_setzero_si128();

	s1 = _mm_unpacklo_epi8(s1, zero);
	s2 = _mm_unpacklo_epi8(s2, zero);

	__m128i r0 = _mm_subs_epi16(s2, s1);
	__m128i r1 = _mm_mullo_epi16(r0, tm);
	__m128i r2 = _mm_srai_epi16(r1, 8);
	__m128i r3 = _mm_adds_epi16(s1, r2);
	__m128i res = _mm_packus_epi16(r3, zero);

	Color o;
	*(int*)&o = _mm_cvtsi128_si32(res);
	return o;
#elif defined(EFK_NEON)

#ifdef __ANDROID__
	uint8x8_t s1 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in1));
	uint8x8_t s2 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in2));
	int16x8_t tm = vmovq_n_s16((int16_t)(t * 256));
	uint16x8_t s3 = vmovl_u8(s1);
	uint16x8_t s4 = vmovl_u8(s2);
	int16x8_t r0 = (int16x8_t)vqsubq_s16((int16x8_t)s4, (int16x8_t)s3);
	int16x8_t r1 = vmulq_s16(r0, tm);
	int16x8_t r2 = vrshrq_n_s16(r1, 8);
	int16x8_t r3 = (int16x8_t)vqaddq_s16((int16x8_t)s3, r2);
	uint8x8_t res = (uint8x8_t)vqmovn_u16((uint16x8_t)r3);

	Color o;
	*(uint32_t*)&o = vget_lane_u32(vreinterpret_u32_u8(res), 0);
	return o;
#else
	uint8x8_t s1 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in1));
	uint8x8_t s2 = vreinterpret_u8_u32(vmov_n_u32(*(uint32_t*)&in2));
	int16x8_t tm = vmovq_n_s16((int16_t)(t * 256));
	uint16x8_t s3 = vmovl_u8(s1);
	uint16x8_t s4 = vmovl_u8(s2);
	int16x8_t r0 = vqsubq_s16(s4, s3);
	int16x8_t r1 = vmulq_s16(r0, tm);
	int16x8_t r2 = vrshrq_n_s16(r1, 8);
	int16x8_t r3 = vqaddq_s16(s3, r2);
	uint8x8_t res = vqmovn_u16(r3);

	Color o;
	*(uint32_t*)&o = vget_lane_u32(vreinterpret_u32_u8(res), 0);
	return o;
#endif

#else
	*/
	Color o;
	o.R = (uint8_t)Clamp(in1.R + (in2.R - in1.R) * t, 255, 0);
	o.G = (uint8_t)Clamp(in1.G + (in2.G - in1.G) * t, 255, 0);
	o.B = (uint8_t)Clamp(in1.B + (in2.B - in1.B) * t, 255, 0);
	o.A = (uint8_t)Clamp(in1.A + (in2.A - in1.A) * t, 255, 0);
	return o;
	//#endif
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------