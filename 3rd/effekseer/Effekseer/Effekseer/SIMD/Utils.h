
#ifndef __EFFEKSEER_SIMD_UTILS_H__
#define __EFFEKSEER_SIMD_UTILS_H__

#include <stdlib.h>
#include "../Effekseer.Vector2D.h"
#include "../Effekseer.Vector3D.h"
#include "../Effekseer.Matrix43.h"
#include "../Effekseer.Matrix44.h"
#include "Float4.h"
#include "Int4.h"
#include "Vec2f.h"
#include "Vec3f.h"
#include "Mat43f.h"
#include "Mat44f.h"

namespace Effekseer
{
	
namespace SIMD
{

template <size_t align>
class AlignedAllocationPolicy {
public:
	static void* operator new(size_t size) {
#if defined(__EMSCRIPTEN__) && __EMSCRIPTEN_minor__ < 38
		return malloc(size);
#elif defined(_MSC_VER)
		return _mm_malloc(size, align);
#else
		void *ptr = nullptr;
		posix_memalign(&ptr, align, size);
		return ptr;
#endif
	}
	static void operator delete(void* ptr) {
#if defined(__EMSCRIPTEN__) && __EMSCRIPTEN_minor__ < 38
		free(ptr);
#elif defined(_MSC_VER)
		_mm_free(ptr);
#else
		return free(ptr);
#endif
	}
};

inline Vector2D ToStruct(const Vec2f& o)
{
	Vector2D ret;
	Vec2f::Store(&ret, o);
	return ret;
}

inline Vector3D ToStruct(const Vec3f& o)
{
	Vector3D ret;
	Vec3f::Store(&ret, o);
	return ret;
}

inline Matrix43 ToStruct(const Mat43f& o)
{
	Float4 tx = o.X;
	Float4 ty = o.Y;
	Float4 tz = o.Z;
	Float4 tw = Float4::SetZero();
	Float4::Transpose(tx, ty, tz, tw);

	Matrix43 ret;
	Float4::Store3(ret.Value[0], tx);
	Float4::Store3(ret.Value[1], ty);
	Float4::Store3(ret.Value[2], tz);
	Float4::Store3(ret.Value[3], tw);
	return ret;
}

inline Matrix44 ToStruct(const Mat44f& o)
{
	Float4 tx = o.X;
	Float4 ty = o.Y;
	Float4 tz = o.Z;
	Float4 tw = o.W;
	Float4::Transpose(tx, ty, tz, tw);

	Matrix44 ret;
	Float4::Store4(ret.Values[0], tx);
	Float4::Store4(ret.Values[1], ty);
	Float4::Store4(ret.Values[2], tz);
	Float4::Store4(ret.Values[3], tw);
	return ret;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_SIMD_UTILS_H__