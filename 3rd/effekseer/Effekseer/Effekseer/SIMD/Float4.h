
#ifndef __EFFEKSEER_SIMD_FLOAT4_H__
#define __EFFEKSEER_SIMD_FLOAT4_H__

#include <cstdint>
#include "Base.h"

#if defined(EFK_SIMD_NEON)
#include "Float4_NEON.h"
#elif defined(EFK_SIMD_SSE2)
#include "Float4_SSE.h"
#else
#include "Float4_Gen.h"
#endif

#endif // __EFFEKSEER_SIMD_FLOAT4_H__