
#ifndef __EFFEKSEER_SIMD_MAT44F_H__
#define __EFFEKSEER_SIMD_MAT44F_H__

#include "Float4.h"
#include "Vec3f.h"
#include "Vec4f.h"
#include "Mat43f.h"

namespace Effekseer
{

struct Matrix44;

namespace SIMD
{

struct Mat44f
{
	Float4 X;
	Float4 Y;
	Float4 Z;
	Float4 W;
	
	Mat44f() = default;
	Mat44f(const Mat44f& rhs) = default;
	Mat44f(float m11, float m12, float m13, float m14,
		   float m21, float m22, float m23, float m24,
		   float m31, float m32, float m33, float m34,
		   float m41, float m42, float m43, float m44);
	Mat44f(const Mat43f& mat);
	Mat44f(const Matrix44& mat);

	bool IsValid() const;

	Vec3f GetScale() const;

	Mat44f GetRotation() const;

	Vec3f GetTranslation() const;

	void GetSRT(Vec3f& s, Mat44f& r, Vec3f& t) const;

	void SetTranslation(const Vec3f& t);

	Mat44f Transpose() const;

	Mat44f& operator*=(const Mat44f& rhs);
	
	Mat44f& operator*=(float rhs);

	static const Mat44f Identity;

	static bool Equal(const Mat44f& lhs, const Mat44f& rhs, float epsilon = DefaultEpsilon);

	static Mat44f SRT(const Vec3f& s, const Mat44f& r, const Vec3f& t);

	static Mat44f Scaling(float x, float y, float z);

	static Mat44f Scaling(const Vec3f& scale);

	static Mat44f RotationX(float angle);

	static Mat44f RotationY(float angle);

	static Mat44f RotationZ(float angle);

	static Mat44f RotationXYZ(float rx, float ry, float rz);

	static Mat44f RotationZXY(float rz, float rx, float ry);

	static Mat44f RotationAxis(const Vec3f& axis, float angle);

	static Mat44f RotationAxis(const Vec3f& axis, float s, float c);

	static Mat44f Translation(float x, float y, float z);

	static Mat44f Translation(const Vec3f& pos);
};

inline Mat44f::Mat44f(
	float m11, float m12, float m13, float m14,
	float m21, float m22, float m23, float m24,
	float m31, float m32, float m33, float m34,
	float m41, float m42, float m43, float m44)
	: X(m11, m21, m31, m41)
	, Y(m12, m22, m32, m42)
	, Z(m13, m23, m33, m43)
	, W(m14, m24, m34, m44)
{
}

inline Mat44f::Mat44f(const Mat43f& mat)
	: X(mat.X)
	, Y(mat.Y)
	, Z(mat.Z)
	, W(0.0f, 0.0f, 0.0f, 1.0f)
{
}

inline bool operator==(const Mat44f& lhs, const Mat44f& rhs)
{
	return lhs.X == rhs.X && lhs.Y == rhs.Y && lhs.Z == rhs.Z && lhs.W == rhs.W;
}

inline bool operator!=(const Mat44f& lhs, const Mat44f& rhs)
{
	return lhs.X != rhs.X && lhs.Y != rhs.Y && lhs.Z != rhs.Z && lhs.W != rhs.W;
}

inline Mat44f operator*(const Mat44f& lhs, const Mat44f& rhs)
{
	Mat44f res;
	res.X = Float4::MulLane<0>(lhs.X, rhs.X);
	res.X = Float4::MulAddLane<1>(res.X, lhs.Y, rhs.X);
	res.X = Float4::MulAddLane<2>(res.X, lhs.Z, rhs.X);
	res.X = Float4::MulAddLane<3>(res.X, lhs.W, rhs.X);

	res.Y = Float4::MulLane<0>(lhs.X, rhs.Y);
	res.Y = Float4::MulAddLane<1>(res.Y, lhs.Y, rhs.Y);
	res.Y = Float4::MulAddLane<2>(res.Y, lhs.Z, rhs.Y);
	res.Y = Float4::MulAddLane<3>(res.Y, lhs.W, rhs.Y);

	res.Z = Float4::MulLane<0>(lhs.X, rhs.Z);
	res.Z = Float4::MulAddLane<1>(res.Z, lhs.Y, rhs.Z);
	res.Z = Float4::MulAddLane<2>(res.Z, lhs.Z, rhs.Z);
	res.Z = Float4::MulAddLane<3>(res.Z, lhs.W, rhs.Z);

	res.W = Float4::MulLane<0>(lhs.X, rhs.W);
	res.W = Float4::MulAddLane<1>(res.W, lhs.Y, rhs.W);
	res.W = Float4::MulAddLane<2>(res.W, lhs.Z, rhs.W);
	res.W = Float4::MulAddLane<3>(res.W, lhs.W, rhs.W);
	return res;
}

inline Vec3f Vec3f::Transform(const Vec3f& lhs, const Mat44f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = rhs.W;
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulAddLane<0>(s3, s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	return Vec3f{res};
}

inline Vec4f Vec4f::Transform(const Vec4f& lhs, const Mat44f& rhs)
{
	Float4 s0 = rhs.X;
	Float4 s1 = rhs.Y;
	Float4 s2 = rhs.Z;
	Float4 s3 = rhs.W;
	Float4::Transpose(s0, s1, s2, s3);

	Float4 res = Float4::MulLane<0>(s0, lhs.s);
	res = Float4::MulAddLane<1>(res, s1, lhs.s);
	res = Float4::MulAddLane<2>(res, s2, lhs.s);
	res = Float4::MulAddLane<3>(res, s3, lhs.s);
	return res;
}

inline Mat44f& Mat44f::operator*=(const Mat44f& rhs)
{
	*this = *this * rhs;
	return *this;
}

inline Mat44f& Mat44f::operator*=(float rhs)
{
	X *= rhs;
	Y *= rhs;
	Z *= rhs;
	W *= rhs;
	return *this;
}

} // namespace SIMD

} // namespace Effekseer

#endif // __EFFEKSEER_VEC4F_H__