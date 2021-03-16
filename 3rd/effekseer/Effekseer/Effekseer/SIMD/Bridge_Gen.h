
#ifndef __EFFEKSEER_SIMD_BRIDGE_GEN_H__
#define __EFFEKSEER_SIMD_BRIDGE_GEN_H__

#include "Float4_Gen.h"
#include "Int4_Gen.h"
#include "Base.h"

#if defined(EFK_SIMD_GEN)

namespace Effekseer
{
	
namespace SIMD
{

inline Int4 Float4::Convert4i() const { return Int4((int32_t)vf[0], (int32_t)vf[1], (int32_t)vf[2], (int32_t)vf[3]); }

inline Int4 Float4::Cast4i() const { return Int4(vu[0], vu[1], vu[2], vu[3]); }

inline Float4 Int4::Convert4f() const { return Float4((float)vi[0], (float)vi[1], (float)vi[2], (float)vi[3]); }

inline Float4 Int4::Cast4f() const { return Float4(vf[0], vf[1], vf[2], vf[3]); }

} // namespace SIMD

} // namespace Effekseer

#endif

#endif // __EFFEKSEER_SIMD_BRIDGE_GEN_H__
