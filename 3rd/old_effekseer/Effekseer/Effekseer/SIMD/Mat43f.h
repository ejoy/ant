
#ifndef __EFFEKSEER_SIMD_MAT43F_H__
#define __EFFEKSEER_SIMD_MAT43F_H__

#include "Float4.h"
#include "Vec3f.h"
#include "Vec4f.h"

namespace Effekseer
{

struct Matrix43;

namespace SIMD
{

struct Mat43f
{
	Float4 X;
	Float4 Y;
	Float4 Z;

	Mat43f() = default;
	Mat43f(const Mat43f& rhs) = default;
	Mat43f(float m11, float m12, float m13,
		   float m21, float m22, float m23,
		   float m31, float m32, float m33,
		   float m41, float m42, float m43);
	Mat43f(const Matrix43& mat);

	bool IsValid() const;

	Vec3f GetScale() const;

	Mat43f GetRotation() const;

	Vec3f GetTranslation() const;

	void GetSRT(Vec3f& s, Mat43f& r, Vec3f& t) const;

	void SetTranslation(const Vec3f& t);

	Mat43f& operator*=(const Mat43f& rhs);

	Mat43f& operator*=(float rhs);

	static const Mat43f Identity;

	static bool Equal(const Mat43f& lhs, const Mat43f& rhs, float epsilon = DefaultEpsilon);

	static Mat43f SRT(const Vec3f& s, const Mat43f& r, const Vec3f& t);

	static Mat43f Scaling(float x, float y, float z);

	static Mat43f Scaling(const Vec3f& scale);

	static Mat43f RotationX(float angle);

	static Mat43f RotationY(float angle);

	static Mat43f RotationZ(float angle);

	static Mat43f RotationXYZ(float rx, float ry, float rz);

	static Mat43f RotationZXY(float rz, float rx, float ry);

	static Mat43f RotationAxis(const Vec3f& axis, float angle);

	static Mat43f RotationAxis(const Vec3f& axis, float s, float c);

	static Mat43f Translation(float x, float y, float z);

	static Mat43f Translation(const Vec3f& pos);
};

inline Mat43f::Mat43f(
	float m11, float m12, float m13,
	float m21, float m22, float m23,
	float m31, float m32, float m33,
	float m41, float m42, float m43)
	: X(m11, m21, m31, m41)
	, Y(m12, m22, m32, m42)
	, Z(m13, m23, m33, m43)
{
}

inline bool operator==(const Mat43f& lhs, const Mat43f& rhs)
{
	return lhs.X == rhs.X && lhs.Y == rhs.Y && lhs.Z == rhs.Z;
}

inline bool operator!=(const Mat43f& lhs, const Mat43f& rhs)
{
	return lhs.X != rhs.X && lhs.Y != rhs.Y && lhs.Z != rhs.Z;
}

inline Mat43f operator*(const Mat43f& lhs, const Mat43f& rhs)
{
	const Float4 mask = Float4::SetUInt(0, 0, 0, 0xffffffff);

	Mat43f res;
	res.X = mask & rhs.X;
	res.X = Float4::MulAddLane<0>(res.X, lhs.X, rhs.X);
	res.X = Float4::MulAddLane<1>(res.X, lhs.Y, rhs.X);
	res.X = Float4::MulAddLane<2>(res.X, lhs.Z, rhs.X);

	res.Y = mask & rhs.Y;
	res.Y = Float4::MulAddLane<0>(res.Y, lhs.X, rhs.Y);
	res.Y = Float4::MulAddLane<1>(res.Y, lhs.Y, rhs.Y);
	res.Y = Float4::MulAddLane<2>(res.Y, lhs.Z, rhs.Y);

	res.Z = mask & rhs.Z;
	res.Z = Float4::MulAddLane<0>(res.Z, lhs.X, rhs.Z);
	res.Z = Float4::MulAddLane<1>(res.Z, lhs.Y, rhs.Z);
	res.Z = Float4::MulAddLane<2>(res.Z, lhs.Z, rhs.Z);
	return res;
}

inline Vec3f Vec3f::Transform(const Vec3f& lhs, const Mat43f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = Float4::SetZero();
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulAddLane<0>(s3, s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	return Vec3f{res};
}

inline Vec4f Vec4f::Transform(const Vec4f& lhs, const Mat43f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = Float4(0.0f, 0.0f, 0.0f, 1.0f);
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulLane<0>(s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	res = Float4::MulAddLane<3>(res, s3, lhs.s);
	return res;
}

inline Mat43f& Mat43f::operator*=(const Mat43f& rhs)
{
	*this = *this * rhs;
	return *this;
}

inline Mat43f& Mat43f::operator*=(float rhs)
{
	X *= rhs;
	Y *= rhs;
	Z *= rhs;
	return *this;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_SIMD_MAT43F_H__