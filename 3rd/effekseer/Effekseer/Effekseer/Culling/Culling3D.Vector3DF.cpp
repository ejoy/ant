
#include "Culling3D.h"

namespace Culling3D
{
Vector3DF::Vector3DF()
	: X(0)
	, Y(0)
	, Z(0)
{
}

Vector3DF::Vector3DF(float x, float y, float z)
	: X(x)
	, Y(y)
	, Z(z)
{
}

bool Vector3DF::operator==(const Vector3DF& o)
{
	return X == o.X && Y == o.Y && Z == o.Z;
}

bool Vector3DF::operator!=(const Vector3DF& o)
{
	return !(X == o.X && Y == o.Y && Z == o.Z);
}

Vector3DF Vector3DF::operator-()
{
	return Vector3DF(-X, -Y, -Z);
}

Vector3DF Vector3DF::operator+(const Vector3DF& o) const
{
	return Vector3DF(X + o.X, Y + o.Y, Z + o.Z);
}

Vector3DF Vector3DF::operator-(const Vector3DF& o) const
{
	return Vector3DF(X - o.X, Y - o.Y, Z - o.Z);
}

Vector3DF Vector3DF::operator*(const Vector3DF& o) const
{
	return Vector3DF(X * o.X, Y * o.Y, Z * o.Z);
}

Vector3DF Vector3DF::operator/(const Vector3DF& o) const
{
	return Vector3DF(X / o.X, Y / o.Y, Z / o.Z);
}

Vector3DF Vector3DF::operator*(const float& o) const
{
	return Vector3DF(X * o, Y * o, Z * o);
}

Vector3DF Vector3DF::operator/(const float& o) const
{
	return Vector3DF(X / o, Y / o, Z / o);
}

Vector3DF& Vector3DF::operator+=(const Vector3DF& o)
{
	X += o.X;
	Y += o.Y;
	Z += o.Z;
	return *this;
}

Vector3DF& Vector3DF::operator-=(const Vector3DF& o)
{
	X -= o.X;
	Y -= o.Y;
	Z -= o.Z;
	return *this;
}

Vector3DF& Vector3DF::operator*=(const float& o)
{
	X *= o;
	Y *= o;
	Z *= o;
	return *this;
}

Vector3DF& Vector3DF::operator/=(const float& o)
{
	X /= o;
	Y /= o;
	Z /= o;
	return *this;
}

float Vector3DF::Dot(const Vector3DF& v1, const Vector3DF& v2)
{
	return v1.X * v2.X + v1.Y * v2.Y + v1.Z * v2.Z;
}

Vector3DF Vector3DF::Cross(const Vector3DF& v1, const Vector3DF& v2)
{
	Vector3DF o;

	float x = v1.Y * v2.Z - v1.Z * v2.Y;
	float y = v1.Z * v2.X - v1.X * v2.Z;
	float z = v1.X * v2.Y - v1.Y * v2.X;
	o.X = x;
	o.Y = y;
	o.Z = z;
	return o;
}

float Vector3DF::Distance(const Vector3DF& v1, const Vector3DF& v2)
{
	float dx = v1.X - v2.X;
	float dy = v1.Y - v2.Y;
	float dz = v1.Z - v2.Z;
	return sqrtf(dx * dx + dy * dy + dz * dz);
}
} // namespace Culling3D