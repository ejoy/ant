
#ifndef __EFFEKSEER_MATH_H__
#define __EFFEKSEER_MATH_H__

#include <cmath>
#include <cstdint>

namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
inline float NormalizeAngle(float angle)
{
	union
	{
		float f;
		int32_t i;
	} ofs, anglebits = {angle};

	ofs.i = (anglebits.i & 0x80000000) | 0x3F000000;
	return angle - ((int)(angle * 0.159154943f + ofs.f) * 6.283185307f);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
inline void SinCos(float x, float& s, float& c)
{
	x = NormalizeAngle(x);
	float x2 = x * x;
	float x4 = x * x * x * x;
	float x6 = x * x * x * x * x * x;
	float x8 = x * x * x * x * x * x * x * x;
	float x10 = x * x * x * x * x * x * x * x * x * x;
	s = x * (1.0f - x2 / 6.0f + x4 / 120.0f - x6 / 5040.0f + x8 / 362880.0f - x10 / 39916800.0f);
	c = 1.0f - x2 / 2.0f + x4 / 24.0f - x6 / 720.0f + x8 / 40320.0f - x10 / 3628800.0f;
}

} // namespace Effekseer

#endif // __EFFEKSEER_MATH_H__