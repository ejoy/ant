
#ifndef __EFFEKSEER_SIMD_BASE_H__
#define __EFFEKSEER_SIMD_BASE_H__

#include <cstdint>
#include <cmath>
#include "../Effekseer.Math.h"

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