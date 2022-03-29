#include "Effekseer.Vector3D.h"
#include "Effekseer.Matrix43.h"
#include "Effekseer.Matrix44.h"
#include "SIMD/Vec3f.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vector3D::Vector3D()
	: X(0.0f)
	, Y(0.0f)
	, Z(0.0f)
{
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vector3D::Vector3D(float x, float y, float z)
	: X(x)
	, Y(y)
	, Z(z)
{
}

Vector3D Vector3D::operator-()
{
	return Vector3D(-X, -Y, -Z);
}

Vector3D Vector3D::operator+(const Vector3D& o) const
{
	return Vector3D(X + o.X, Y + o.Y, Z + o.Z);
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D Vector3D::operator-(const Vector3D& o) const
{
	return Vector3D(X - o.X, Y - o.Y, Z - o.Z);
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D Vector3D::operator*(const float& o) const
{
	return Vector3D(X * o, Y * o, Z * o);
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D Vector3D::operator/(const float& o) const
{
	return Vector3D(X / o, Y / o, Z / o);
}

Vector3D Vector3D::operator*(const Vector3D& o) const
{
	return Vector3D(X * o.X, Y * o.Y, Z * o.Z);
}

Vector3D Vector3D::operator/(const Vector3D& o) const
{
	return Vector3D(X / o.X, Y / o.Y, Z / o.Z);
}

bool Vector3D::operator==(const Vector3D& o)
{
	return this->X == o.X && this->Y == o.Y && this->Z == o.Z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Vector3D::Add(Vector3D* pOut, const Vector3D* pIn1, const Vector3D* pIn2)
{
	float x = pIn1->X + pIn2->X;
	float y = pIn1->Y + pIn2->Y;
	float z = pIn1->Z + pIn2->Z;
	pOut->X = x;
	pOut->Y = y;
	pOut->Z = z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vector3D& Vector3D::Sub(Vector3D& o, const Vector3D& in1, const Vector3D& in2)
{
	o.X = in1.X - in2.X;
	o.Y = in1.Y - in2.Y;
	o.Z = in1.Z - in2.Z;
	return o;
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D& Vector3D::operator+=(const Vector3D& o)
{
	X += o.X;
	Y += o.Y;
	Z += o.Z;
	return *this;
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D& Vector3D::operator-=(const Vector3D& o)
{
	X -= o.X;
	Y -= o.Y;
	Z -= o.Z;
	return *this;
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D& Vector3D::operator*=(const float& o)
{
	X *= o;
	Y *= o;
	Z *= o;
	return *this;
}

//-----------------------------------------------------------------------------------
//
//-----------------------------------------------------------------------------------
Vector3D& Vector3D::operator/=(const float& o)
{
	X /= o;
	Y /= o;
	Z /= o;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
float Vector3D::Length(const Vector3D& in)
{
	return sqrt(in.X * in.X + in.Y * in.Y + in.Z * in.Z);
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
float Vector3D::LengthSq(const Vector3D& in)
{
	return in.X * in.X + in.Y * in.Y + in.Z * in.Z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
float Vector3D::Dot(const Vector3D& in1, const Vector3D& in2)
{
	return in1.X * in2.X + in1.Y * in2.Y + in1.Z * in2.Z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Vector3D::Normal(Vector3D& o, const Vector3D& in)
{
	float inv = SIMD::Rsqrt(in.X * in.X + in.Y * in.Y + in.Z * in.Z);
	o.X = in.X * inv;
	o.Y = in.Y * inv;
	o.Z = in.Z * inv;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vector3D& Vector3D::Cross(Vector3D& o, const Vector3D& in1, const Vector3D& in2)
{
	float x = in1.Y * in2.Z - in1.Z * in2.Y;
	float y = in1.Z * in2.X - in1.X * in2.Z;
	float z = in1.X * in2.Y - in1.Y * in2.X;
	o.X = x;
	o.Y = y;
	o.Z = z;
	return o;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vector3D& Vector3D::Transform(Vector3D& o, const Vector3D& in, const Matrix43& mat)
{
	float values[4];
	for (int i = 0; i < 3; i++)
	{
		values[i] = 0;
		values[i] += in.X * mat.Value[0][i];
		values[i] += in.Y * mat.Value[1][i];
		values[i] += in.Z * mat.Value[2][i];
		values[i] += mat.Value[3][i];
	}
	o.X = values[0];
	o.Y = values[1];
	o.Z = values[2];
	return o;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Vector3D& Vector3D::Transform(Vector3D& o, const Vector3D& in, const Matrix44& mat)
{
	float values[3];

	for (int i = 0; i < 3; i++)
	{
		values[i] = 0;
		values[i] += in.X * mat.Values[0][i];
		values[i] += in.Y * mat.Values[1][i];
		values[i] += in.Z * mat.Values[2][i];
		values[i] += mat.Values[3][i];
	}

	o.X = values[0];
	o.Y = values[1];
	o.Z = values[2];
	return o;
}

Vector3D& Vector3D::TransformWithW(Vector3D& o, const Vector3D& in, const Matrix44& mat)
{
	float values[4];

	for (int i = 0; i < 4; i++)
	{
		values[i] = 0;
		values[i] += in.X * mat.Values[0][i];
		values[i] += in.Y * mat.Values[1][i];
		values[i] += in.Z * mat.Values[2][i];
		values[i] += mat.Values[3][i];
	}

	o.X = values[0] / values[3];
	o.Y = values[1] / values[3];
	o.Z = values[2] / values[3];
	return o;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
  //----------------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------------