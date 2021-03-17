
#ifndef __EFFEKSEER_SIMD_BRIDGE_SSE_H__
#define __EFFEKSEER_SIMD_BRIDGE_SSE_H__

#include "Float4_SSE.h"
#include "Int4_SSE.h"
#include "Base.h"

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