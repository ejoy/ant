
#ifndef __EFFEKSEER_SIMD_VEC3F_H__
#define __EFFEKSEER_SIMD_VEC3F_H__

#include "../Effekseer.Math.h"
#include "Float4.h"
#include <functional>

namespace Effekseer
{

struct Vector3D;
struct vector3d;

namespace SIMD
{

struct Mat43f;
struct Mat44f;

struct Vec3f
{
	Float4 s;

	explicit Vec3f() = default;
	Vec3f(const Vec3f& vec) = default;
	Vec3f(float x, float y, float z)
		: s(x, y, z, 1.0f)
	{
	}
	Vec3f(const Float4& vec)
		: s(vec)
	{
	}
	Vec3f(const Vector3D& vec);
	Vec3f(const vector3d& vec);
	Vec3f(const std::array<float, 3>& vec);

	float GetX() const
	{
		return s.GetX();
	}
	float GetY() const
	{
		return s.GetY();
	}
	float GetZ() const
	{
		return s.GetZ();
	}

	void SetX(float o)
	{
		s.SetX(o);
	}
	void SetY(float o)
	{
		s.SetY(o);
	}
	void SetZ(float o)
	{
		s.SetZ(o);
	}

	Vec3f& operator+=(const Vec3f& o)
	{
		s += o.s;
		return *this;
	}
	Vec3f& operator-=(const Vec3f& o)
	{
		s -= o.s;
		return *this;
	}
	Vec3f& operator*=(const Vec3f& o)
	{
		s *= o.s;
		return *this;
	}
	Vec3f& operator*=(float o)
	{
		s *= o;
		return *this;
	}
	Vec3f& operator/=(const Vec3f& o)
	{
		s /= o.s;
		return *this;
	}
	Vec3f& operator/=(float o)
	{
		s /= o;
		return *this;
	}

	float GetSquaredLength() const;
	float GetLength() const;
	bool IsZero(float epsiron = DefaultEpsilon) const;
	Vec3f Normalize() const;
	Vec3f NormalizePrecisely() const;
	Vec3f NormalizeFast() const;

	static Vec3f Load(const void* mem);
	static void Store(void* mem, const Vec3f& i);

	static Vec3f Sqrt(const Vec3f& i);
	static Vec3f Rsqrt(const Vec3f& i);
	static Vec3f Abs(const Vec3f& i);
	static Vec3f Min(const Vec3f& lhs, const Vec3f& rhs);
	static Vec3f Max(const Vec3f& lhs, const Vec3f& rhs);
	static float Dot(const Vec3f& lhs, const Vec3f& rhs);
	static Vec3f Cross(const Vec3f& lhs, const Vec3f& rhs);
	static bool Equal(const Vec3f& lhs, const Vec3f& rhs, float epsilon = DefaultEpsilon);
	static Vec3f Transform(const Vec3f& lhs, const Mat43f& rhs);
	static Vec3f Transform(const Vec3f& lhs, const Mat44f& rhs);
};

inline Vec3f operator-(const Vec3f& i)
{
	return Vec3f(-i.GetX(), -i.GetY(), -i.GetZ());
}

inline Vec3f operator+(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s + rhs.s};
}

inline Vec3f operator-(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s - rhs.s};
}

inline Vec3f operator*(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s * rhs.s};
}

inline Vec3f operator*(const Vec3f& lhs, float rhs)
{
	return Vec3f{lhs.s * rhs};
}

inline Vec3f operator/(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{lhs.s / rhs.s};
}

inline Vec3f operator/(const Vec3f& lhs, float rhs)
{
	return Vec3f{lhs.s / rhs};
}

inline bool operator==(const Vec3f& lhs, const Vec3f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x07) == 0x7;
}

inline bool operator!=(const Vec3f& lhs, const Vec3f& rhs)
{
	return (Float4::MoveMask(Float4::Equal(lhs.s, rhs.s)) & 0x07) != 0x7;
}

inline Vec3f Vec3f::Load(const void* mem)
{
	return Float4::Load3(mem);
}

inline void Vec3f::Store(void* mem, const Vec3f& i)
{
	Float4::Store3(mem, i.s);
}

inline Vec3f Vec3f::Sqrt(const Vec3f& i)
{
	return Vec3f{Float4::Sqrt(i.s)};
}

inline Vec3f Vec3f::Rsqrt(const Vec3f& i)
{
	return Vec3f{Float4::Rsqrt(i.s)};
}

inline Vec3f Vec3f::Abs(const Vec3f& i)
{
	return Vec3f{Float4::Abs(i.s)};
}

inline Vec3f Vec3f::Min(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{Float4::Min(lhs.s, rhs.s)};
}

inline Vec3f Vec3f::Max(const Vec3f& lhs, const Vec3f& rhs)
{
	return Vec3f{Float4::Max(lhs.s, rhs.s)};
}

inline float Vec3f::Dot(const Vec3f& lhs, const Vec3f& rhs)
{
	return Float4::Dot3(lhs.s, rhs.s).GetX();
}

inline Vec3f Vec3f::Cross(const Vec3f& lhs, const Vec3f& rhs)
{
	return Float4::Cross3(lhs.s, rhs.s);
}

inline bool Vec3f::Equal(const Vec3f& lhs, const Vec3f& rhs, float epsilon)
{
	return (Float4::MoveMask(Float4::NearEqual(lhs.s, rhs.s, epsilon)) & 0x7) == 0x7;
}

inline float Vec3f::GetSquaredLength() const
{
	auto o = s * s;
	return o.GetX() + o.GetY() + o.GetZ();
}

inline float Vec3f::GetLength() const
{
	return Effekseer::SIMD::Sqrt(GetSquaredLength());
}

inline bool Vec3f::IsZero(float epsiron) const
{
	return (Float4::MoveMask(Float4::IsZero(s, epsiron)) & 0x7) == 0x7;
}

inline Vec3f Vec3f::Normalize() const
{
	return *this * Effekseer::SIMD::Rsqrt(GetSquaredLength());
}

inline Vec3f Vec3f::NormalizePrecisely() const
{
	return *this / Effekseer::SIMD::Sqrt(GetSquaredLength());
}

inline Vec3f Vec3f::NormalizeFast() const
{
	return *this * Effekseer::SIMD::Rsqrt(GetSquaredLength());
}

} // namespace SIMD

} // namespace Effekseer

namespace std
{

template <>
struct hash<Effekseer::SIMD::Vec3f>
{
	size_t operator()(const Effekseer::SIMD::Vec3f& _Keyval) const noexcept
	{
		return std::hash<float>()(_Keyval.GetX()) + std::hash<float>()(_Keyval.GetY()) + std::hash<float>()(_Keyval.GetZ());
	}
};

} // namespace std

#endif // __EFFEKSEER_SIMD_VEC3F_H__