
#ifndef __EFFEKSEER_SIMD_VEC4F_H__
#define __EFFEKSEER_SIMD_VEC4F_H__

#include "Float4.h"
#include "../Effekseer.Math.h"

namespace Effekseer
{
	
namespace SIMD
{

struct Vec4f
{
	Float4 s;

	Vec4f() = default;
	Vec4f(const Vec4f& vec) = default;
	Vec4f(const Float4& vec): s(vec) {}

	float GetX() const { return s.GetX(); }
	float GetY() const { return s.GetY(); }
	float GetZ() const { return s.GetZ(); }
	float GetW() const { return s.GetW(); }

	void SetX(float o) { s.SetX(o); }
	void SetY(float o) { s.SetY(o); }
	void SetZ(float o) { s.SetZ(o); }
	void SetW(float o) { s.SetW(o); }

	Vec4f& operator+=(const Vec4f& o)
	{
		this->s = this->s + o.s;
		return *this;
	}

	Vec4f& operator-=(const Vec4f& o)
	{
		this->s = this->s - o.s;
		return *this;
	}

	Vec4f& operator*=(const Vec4f& o)
	{
		this->s = this->s * o.s;
		return *this;
	}

	Vec4f& operator/=(const Vec4f& o)
	{
		this->s = this->s / o.s;
		return *this;
	}

	static Vec4f Sqrt(const Vec4f& i);
	static Vec4f Rsqrt(const Vec4f& i);
	static Vec4f Abs(const Vec4f& i);
	static Vec4f Min(const Vec4f& lhs, const Vec4f& rhs);
	static Vec4f Max(const Vec4f& lhs, const Vec4f& rhs);
	static bool Equal(const Vec4f& lhs, const Vec4f& rhs, float epsilon);
	static Vec4f Transform(const Vec4f& lhs, const Mat43f& rhs);
	static Vec4f Transform(const Vec4f& lhs, const Mat44f& rhs);
};

inline Vec4f operator+(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s + rhs.s}; }

inline Vec4f operator-(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s - rhs.s}; }

inline Vec4f operator*(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s * rhs.s}; }

inline Vec4f operator/(const Vec4f& lhs, const Vec4f& rhs) { return Vec4f{lhs.s / rhs.s}; }

inline bool operator==(const Vec4f& lhs, const Vec4f& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) == 0xf;
}

inline bool operator!=(const Vec4f& lhs, const Vec4f& rhs)
{
	return Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) != 0xf;
}

inline Vec4f Vec4f::Sqrt(const Vec4f& i)
{
	return Vec4f{Float4::Sqrt(i.s)};
}

inline Vec4f Vec4f::Rsqrt(const Vec4f& i)
{
	return Vec4f{Float4::Rsqrt(i.s)};
}

inline Vec4f Vec4f::Abs(const Vec4f& i)
{
	return Vec4f{Float4::Abs(i.s)};
}

inline Vec4f Vec4f::Min(const Vec4f& lhs, const Vec4f& rhs)
{
	return Vec4f{Float4::Min(lhs.s, rhs.s)};
}

inline Vec4f Vec4f::Max(const Vec4f& lhs, const Vec4f& rhs)
{
	return Vec4f{Float4::Max(lhs.s, rhs.s)};
}

inline bool Vec4f::Equal(const Vec4f& lhs, const Vec4f& rhs, float epsilon)
{
	return (Float4::MoveMask(Float4::NearEqual(lhs.s, rhs.s, epsilon)) & 0xf) == 0xf;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_SIMD_VEC4F_H__