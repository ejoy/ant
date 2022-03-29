
#ifndef __EFFEKSEER_SIMD_VEC2F_H__
#define __EFFEKSEER_SIMD_VEC2F_H__

#include "Float4.h"
#include "../Effekseer.Math.h"

namespace Effekseer
{

struct Vector2D;
struct vector2d;

namespace SIMD
{

struct Vec2f
{
	Float4 s;

	explicit Vec2f() = default;
	Vec2f(const Vec2f& vec) = default;
	Vec2f(float x, float y): s(x, y, 0.0f, 1.0f) {}
	Vec2f(const std::array<float, 2>& v): s(v[0], v[1], 0.0f, 1.0f) {}
	Vec2f(const Float4& vec): s(vec) {}
	Vec2f(const Vector2D& vec);
	Vec2f(const vector2d& vec);

	float GetX() const { return s.GetX(); }
	float GetY() const { return s.GetY(); }

	void SetX(float o) { s.SetX(o); }
	void SetY(float o) { s.SetY(o); }

	Vec2f& operator+=(const Vec2f& o) { s += o.s; return *this; }
	Vec2f& operator-=(const Vec2f& o) { s -= o.s; return *this; }
	Vec2f& operator*=(const Vec2f& o) { s *= o.s; return *this; }
	Vec2f& operator*=(float o) { s *= o; return *this; }
	Vec2f& operator/=(const Vec2f& o) { s /= o.s; return *this; }
	Vec2f& operator/=(float o) { s /= o; return *this; }

	float LengthSq() const;
	float Length() const;
	bool IsZero(float range = DefaultEpsilon) const;
	Vec2f Normalize() const;

	static Vec2f Load(const void* mem);
	static void Store(void* mem, const Vec2f& i);

	static Vec2f Sqrt(const Vec2f& i);
	static Vec2f Rsqrt(const Vec2f& i);
	static Vec2f Abs(const Vec2f& i);
	static Vec2f Min(const Vec2f& lhs, const Vec2f& rhs);
	static Vec2f Max(const Vec2f& lhs, const Vec2f& rhs);
	static bool Equal(const Vec2f& lhs, const Vec2f& rhs, float epsilon);
};

inline Vec2f operator+(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s + rhs.s};
}

inline Vec2f operator-(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s - rhs.s};
}

inline Vec2f operator*(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s * rhs.s};
}

inline Vec2f operator*(const Vec2f& lhs, float rhs)
{
	return Vec2f{lhs.s * rhs};
}

inline Vec2f operator/(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{lhs.s / rhs.s};
}

inline Vec2f operator/(const Vec2f& lhs, float rhs)
{
	return Vec2f{lhs.s / rhs};
}

inline bool operator==(const Vec2f& lhs, const Vec2f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x03) == 0x3;
}

inline bool operator!=(const Vec2f& lhs, const Vec2f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x03) != 0x3;
}

inline Vec2f Vec2f::Load(const void* mem)
{
	return Float4::Load2(mem);
}

inline void Vec2f::Store(void* mem, const Vec2f& i)
{
	Float4::Store2(mem, i.s);
}

inline Vec2f Vec2f::Sqrt(const Vec2f& i)
{
	return Vec2f{Float4::Sqrt(i.s)};
}

inline Vec2f Vec2f::Rsqrt(const Vec2f& i)
{
	return Vec2f{Float4::Rsqrt(i.s)};
}

inline Vec2f Vec2f::Abs(const Vec2f& i)
{
	return Vec2f{Float4::Abs(i.s)};
}

inline Vec2f Vec2f::Min(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{Float4::Min(lhs.s, rhs.s)};
}

inline Vec2f Vec2f::Max(const Vec2f& lhs, const Vec2f& rhs)
{
	return Vec2f{Float4::Max(lhs.s, rhs.s)};
}

inline bool Vec2f::Equal(const Vec2f& lhs, const Vec2f& rhs, float epsilon)
{
	return (Float4::MoveMask(Float4::NearEqual(lhs.s, rhs.s, epsilon)) & 0x3) == 0x3;
}

inline float Vec2f::LengthSq() const
{
	auto o = s * s;
	return o.GetX() + o.GetY();
}

inline float Vec2f::Length() const
{
	return Effekseer::SIMD::Sqrt(LengthSq());
}

inline bool Vec2f::IsZero(float range) const
{
	return LengthSq() < range * range;
}

inline Vec2f Vec2f::Normalize() const
{
	return *this * Effekseer::SIMD::Rsqrt(LengthSq());
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_VEC2F_H__