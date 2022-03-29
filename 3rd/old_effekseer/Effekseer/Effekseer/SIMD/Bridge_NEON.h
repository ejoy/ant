
#ifndef __EFFEKSEER_SIMD_BRIDGE_NEON_H__
#define __EFFEKSEER_SIMD_BRIDGE_NEON_H__

#include "Float4_NEON.h"
#include "Int4_NEON.h"
#include "Base.h"

#if defined(EFK_SIMD_NEON)

namespace Effekseer
{
	
namespace SIMD
{

inline Int4 Float4::Convert4i() const { return vcvtq_s32_f32(s); }

inline Int4 Float4::Cast4i() const { return vreinterpretq_s32_f32(s); }

inline Float4 Int4::Convert4f() const { return vcvtq_f32_s32(s); }

inline Float4 Int4::Cast4f() const { return vreinterpretq_f32_s32(s); }

} // namespace SIMD

} // namespace Effekseer

#endif
#endif // __EFFEKSEER_SIMD_BRIDGE_NEON_H__
