
#ifndef __EFFEKSEER_SPLINE_GENERATOR_H__
#define __EFFEKSEER_SPLINE_GENERATOR_H__

#include "../SIMD/Vec3f.h"
#include "../Utils/Effekseer.CustomAllocator.h"
#include <cstdint>
#include <vector>

namespace Effekseer
{

/**
	@brief Spline generator
	@note
	Reference https://qiita.com/edo_m18/items/f2f0c6bf9032b0ec12d4
*/
class SplineGenerator
{
	CustomAlignedVector<SIMD::Vec3f> a;
	CustomAlignedVector<SIMD::Vec3f> b;
	CustomAlignedVector<SIMD::Vec3f> c;
	CustomAlignedVector<SIMD::Vec3f> d;
	CustomAlignedVector<SIMD::Vec3f> w;
	CustomVector<bool> isSame;
	CustomVector<float> distances_;

public:
	void AddVertex(const SIMD::Vec3f& v);

	void Calculate();

	void CalculateDistances();

	void Reset();

	SIMD::Vec3f GetValue(float t) const;
};

} // namespace Effekseer

#endif