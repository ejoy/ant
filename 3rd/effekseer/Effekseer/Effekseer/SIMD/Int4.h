
#ifndef __EFFEKSEER_SIMD_INT4_H__
#define __EFFEKSEER_SIMD_INT4_H__

#include <cstdint>
#include "Base.h"

#if defined(EFK_SIMD_NEON)
#include "Int4_NEON.h"
#elif defined(EFK_SIMD_SSE2)
#include "Int4_SSE.h"
#else
#include "Int4_Gen.h"
#endif

#endif // __EFFEKSEER_SIMD_INT4_H__