#include "Mat43f.h"
#include "../Effekseer.Matrix43.h"
#include <cmath>

namespace Effekseer
{

namespace SIMD
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
const Mat43f Mat43f::Identity = Mat43f(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0);

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f::Mat43f(const Matrix43& mat)
{
	X = Float4::Load3(mat.Value[0]);
	Y = Float4::Load3(mat.Value[1]);
	Z = Float4::Load3(mat.Value[2]);
	Float4 W = Float4::Load3(mat.Value[3]);
	Float4::Transpose(X, Y, Z, W);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
bool Mat43f::IsValid() const
{
	const Float4 nan{NAN};
	const Float4 inf{INFINITY};
	Float4 res = Float4::Equal(X, nan) | Float4::Equal(Y, nan) | Float4::Equal(Z, nan) | Float4::Equal(X, inf) | Float4::Equal(Y, inf) |
				 Float4::Equal(Z, inf);
	return Float4::MoveMask(res) == 0;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vec3f Mat43f::GetScale() const
{
	Float4 x2 = X * X;
	Float4 y2 = Y * Y;
	Float4 z2 = Z * Z;
	Float4 s2 = x2 + y2 + z2;
	Float4 sq = Float4::Sqrt(s2);
	return Vec3f{sq};
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::GetRotation() const
{
	Float4 x2 = X * X;
	Float4 y2 = Y * Y;
	Float4 z2 = Z * Z;
	Float4 s2 = x2 + y2 + z2;
	Float4 rsq = Float4::Rsqrt(s2);
	rsq.SetW(0.0f);

	Mat43f ret;
	ret.X = X * rsq;
	ret.Y = Y * rsq;
	ret.Z = Z * rsq;
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vec3f Mat43f::GetTranslation() const
{
	return Vec3f(X.GetW(), Y.GetW(), Z.GetW());
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Mat43f::GetSRT(Vec3f& s, Mat43f& r, Vec3f& t) const
{
	Float4 x2 = X * X;
	Float4 y2 = Y * Y;
	Float4 z2 = Z * Z;
	Float4 s2 = x2 + y2 + z2;

	if (Vec3f(s2).IsZero())
	{
		s = Vec3f(0.0f);
		r = Mat43f::Identity;
	}
	else
	{
		Float4 rsq = Float4::Rsqrt(s2);
		rsq.SetW(0.0f);

		s = Float4(1.0f) / rsq;
		r.X = X * rsq;
		r.Y = Y * rsq;
		r.Z = Z * rsq;
	}

	t = Vec3f(X.GetW(), Y.GetW(), Z.GetW());
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Mat43f::SetTranslation(const Vec3f& t)
{
	X.SetW(t.GetX());
	Y.SetW(t.GetY());
	Z.SetW(t.GetZ());
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
bool Mat43f::Equal(const Mat43f& lhs, const Mat43f& rhs, float epsilon)
{
	Float4 ret =
		Float4::NearEqual(lhs.X, rhs.X, epsilon) & Float4::NearEqual(lhs.Y, rhs.Y, epsilon) & Float4::NearEqual(lhs.Z, rhs.Z, epsilon);
	return (Float4::MoveMask(ret) & 0xf) == 0xf;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::SRT(const Vec3f& s, const Mat43f& r, const Vec3f& t)
{
	Mat43f ret;
	ret.X = r.X * s.s;
	ret.Y = r.Y * s.s;
	ret.Z = r.Z * s.s;
	ret.X.SetW(t.GetX());
	ret.Y.SetW(t.GetY());
	ret.Z.SetW(t.GetZ());
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::Scaling(float x, float y, float z)
{
	Mat43f ret;
	ret.X = {x, 0.0f, 0.0f, 0.0f};
	ret.Y = {0.0f, y, 0.0f, 0.0f};
	ret.Z = {0.0f, 0.0f, z, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::Scaling(const Vec3f& scale)
{
	Mat43f ret;
	ret.X = {scale.GetX(), 0.0f, 0.0f, 0.0f};
	ret.Y = {0.0f, scale.GetY(), 0.0f, 0.0f};
	ret.Z = {0.0f, 0.0f, scale.GetZ(), 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationX(float angle)
{
	float c, s;
	::Effekseer::SinCos(angle, s, c);

	Mat43f ret;
	ret.X = {1.0f, 0.0f, 0.0f, 0.0f};
	ret.Y = {0.0f, c, -s, 0.0f};
	ret.Z = {0.0f, s, c, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationY(float angle)
{
	float c, s;
	::Effekseer::SinCos(angle, s, c);

	Mat43f ret;
	ret.X = {c, 0.0f, s, 0.0f};
	ret.Y = {0.0f, 1.0f, 0.0f, 0.0f};
	ret.Z = {-s, 0.0f, c, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationZ(float angle)
{
	float c, s;
	::Effekseer::SinCos(angle, s, c);

	Mat43f ret;
	ret.X = {c, -s, 0.0f, 0.0f};
	ret.Y = {s, c, 0.0f, 0.0f};
	ret.Z = {0.0f, 0.0f, 1.0f, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationXYZ(float rx, float ry, float rz)
{
	float cx, sx, cy, sy, cz, sz;

	if (rx != 0.0f)
	{
		::Effekseer::SinCos(rx, sx, cx);
	}
	else
	{
		sx = 0.0f;
		cx = 1.0f;
	}
	if (ry != 0.0f)
	{
		::Effekseer::SinCos(ry, sy, cy);
	}
	else
	{
		sy = 0.0f;
		cy = 1.0f;
	}
	if (rz != 0.0f)
	{
		::Effekseer::SinCos(rz, sz, cz);
	}
	else
	{
		sz = 0.0f;
		cz = 1.0f;
	}

	float m00 = cy * cz;
	float m01 = cy * sz;
	float m02 = -sy;

	float m10 = sx * sy * -sz + cx * -sz;
	float m11 = sx * sy * sz + cx * cz;
	float m12 = sx * cy;

	float m20 = cx * sy * cz + sx * sz;
	float m21 = cx * sy * sz - sx * cz;
	float m22 = cx * cy;

	Mat43f ret;
	ret.X = {m00, m10, m20, 0.0f};
	ret.Y = {m01, m11, m21, 0.0f};
	ret.Z = {m02, m12, m22, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationZXY(float rz, float rx, float ry)
{
	float cx, sx, cy, sy, cz, sz;

	if (rx != 0.0f)
	{
		::Effekseer::SinCos(rx, sx, cx);
	}
	else
	{
		sx = 0.0f;
		cx = 1.0f;
	}
	if (ry != 0.0f)
	{
		::Effekseer::SinCos(ry, sy, cy);
	}
	else
	{
		sy = 0.0f;
		cy = 1.0f;
	}
	if (rz != 0.0f)
	{
		::Effekseer::SinCos(rz, sz, cz);
	}
	else
	{
		sz = 0.0f;
		cz = 1.0f;
	}

	float m00 = cz * cy + sz * sx * sy;
	float m01 = sz * cx;
	float m02 = cz * -sy + sz * sx * cy;

	float m10 = -sz * cy + cz * sx * sy;
	float m11 = cz * cx;
	float m12 = -sz * -sy + cz * sx * cy;

	float m20 = cx * sy;
	float m21 = -sx;
	float m22 = cx * cy;

	Mat43f ret;
	ret.X = {m00, m10, m20, 0.0f};
	ret.Y = {m01, m11, m21, 0.0f};
	ret.Z = {m02, m12, m22, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationAxis(const Vec3f& axis, float angle)
{
	const float c = cosf(angle);
	const float s = sinf(angle);
	return RotationAxis(axis, s, c);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::RotationAxis(const Vec3f& axis, float s, float c)
{
	const float cc = 1.0f - c;

	float m00 = cc * (axis.GetX() * axis.GetX()) + c;
	float m01 = cc * (axis.GetX() * axis.GetY()) + (axis.GetZ() * s);
	float m02 = cc * (axis.GetZ() * axis.GetX()) - (axis.GetY() * s);

	float m10 = cc * (axis.GetX() * axis.GetY()) - (axis.GetZ() * s);
	float m11 = cc * (axis.GetY() * axis.GetY()) + c;
	float m12 = cc * (axis.GetY() * axis.GetZ()) + (axis.GetX() * s);

	float m20 = cc * (axis.GetZ() * axis.GetX()) + (axis.GetY() * s);
	float m21 = cc * (axis.GetY() * axis.GetZ()) - (axis.GetX() * s);
	float m22 = cc * (axis.GetZ() * axis.GetZ()) + c;

	Mat43f ret;
	ret.X = {m00, m10, m20, 0.0f};
	ret.Y = {m01, m11, m21, 0.0f};
	ret.Z = {m02, m12, m22, 0.0f};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::Translation(float x, float y, float z)
{
	Mat43f ret;
	ret.X = {1.0f, 0.0f, 0.0f, x};
	ret.Y = {0.0f, 1.0f, 0.0f, y};
	ret.Z = {0.0f, 0.0f, 1.0f, z};
	return ret;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Mat43f Mat43f::Translation(const Vec3f& pos)
{
	Mat43f ret;
	ret.X = {1.0f, 0.0f, 0.0f, pos.GetX()};
	ret.Y = {0.0f, 1.0f, 0.0f, pos.GetY()};
	ret.Z = {0.0f, 0.0f, 1.0f, pos.GetZ()};
	return ret;
}

} // namespace SIMD

} // namespace Effekseer
