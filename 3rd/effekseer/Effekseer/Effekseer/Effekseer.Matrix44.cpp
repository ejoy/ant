

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
#include "Effekseer.Matrix44.h"
#include "Effekseer.Math.h"
#include "Effekseer.Vector3D.h"

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
namespace Effekseer
{
//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44::Matrix44()
{
	Indentity();
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::Indentity()
{
	memset(Values, 0, sizeof(float) * 16);
	Values[0][0] = 1.0f;
	Values[1][1] = 1.0f;
	Values[2][2] = 1.0f;
	Values[3][3] = 1.0f;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::Transpose()
{
	for (int32_t c = 0; c < 4; c++)
	{
		for (int32_t r = c; r < 4; r++)
		{
			float v = Values[r][c];
			Values[r][c] = Values[c][r];
			Values[c][r] = v;
		}
	}

	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::LookAtRH(const Vector3D& eye, const Vector3D& at, const Vector3D& up)
{
	// F=正面、R=右方向、U=上方向
	Vector3D F;
	Vector3D R;
	Vector3D U;
	Vector3D::Normal(F, Vector3D::Sub(F, eye, at));
	Vector3D::Normal(R, Vector3D::Cross(R, up, F));
	Vector3D::Normal(U, Vector3D::Cross(U, F, R));

	Values[0][0] = R.X;
	Values[1][0] = R.Y;
	Values[2][0] = R.Z;
	Values[3][0] = 0.0f;

	Values[0][1] = U.X;
	Values[1][1] = U.Y;
	Values[2][1] = U.Z;
	Values[3][1] = 0.0f;

	Values[0][2] = F.X;
	Values[1][2] = F.Y;
	Values[2][2] = F.Z;
	Values[3][2] = 0.0f;

	Values[3][0] = -Vector3D::Dot(R, eye);
	Values[3][1] = -Vector3D::Dot(U, eye);
	Values[3][2] = -Vector3D::Dot(F, eye);
	Values[3][3] = 1.0f;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::LookAtLH(const Vector3D& eye, const Vector3D& at, const Vector3D& up)
{
	// F=正面、R=右方向、U=上方向
	Vector3D F;
	Vector3D R;
	Vector3D U;
	Vector3D::Normal(F, Vector3D::Sub(F, at, eye));
	Vector3D::Normal(R, Vector3D::Cross(R, up, F));
	Vector3D::Normal(U, Vector3D::Cross(U, F, R));

	Values[0][0] = R.X;
	Values[1][0] = R.Y;
	Values[2][0] = R.Z;
	Values[3][0] = 0.0f;

	Values[0][1] = U.X;
	Values[1][1] = U.Y;
	Values[2][1] = U.Z;
	Values[3][1] = 0.0f;

	Values[0][2] = F.X;
	Values[1][2] = F.Y;
	Values[2][2] = F.Z;
	Values[3][2] = 0.0f;

	Values[3][0] = -Vector3D::Dot(R, eye);
	Values[3][1] = -Vector3D::Dot(U, eye);
	Values[3][2] = -Vector3D::Dot(F, eye);
	Values[3][3] = 1.0f;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::PerspectiveFovRH(float ovY, float aspect, float zn, float zf)
{
	float yScale = 1 / tanf(ovY / 2);
	float xScale = yScale / aspect;

	Values[0][0] = xScale;
	Values[0][1] = 0;
	Values[0][2] = 0;
	Values[0][3] = 0;

	Values[1][0] = 0;
	Values[1][1] = yScale;
	Values[1][2] = 0;
	Values[1][3] = 0;

	Values[2][0] = 0;
	Values[2][1] = 0;
	Values[2][2] = zf / (zn - zf);
	Values[2][3] = -1;

	Values[3][0] = 0;
	Values[3][1] = 0;
	Values[3][2] = zn * zf / (zn - zf);
	Values[3][3] = 0;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::PerspectiveFovRH_OpenGL(float ovY, float aspect, float zn, float zf)
{
	float yScale = 1 / tanf(ovY / 2);
	float xScale = yScale / aspect;
	float dz = zf - zn;

	Values[0][0] = xScale;
	Values[0][1] = 0;
	Values[0][2] = 0;
	Values[0][3] = 0;

	Values[1][0] = 0;
	Values[1][1] = yScale;
	Values[1][2] = 0;
	Values[1][3] = 0;

	Values[2][0] = 0;
	Values[2][1] = 0;
	Values[2][2] = -(zf + zn) / dz;
	Values[2][3] = -1.0f;

	Values[3][0] = 0;
	Values[3][1] = 0;
	Values[3][2] = -2.0f * zn * zf / dz;
	Values[3][3] = 0.0f;

	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::PerspectiveFovLH(float ovY, float aspect, float zn, float zf)
{
	float yScale = 1 / tanf(ovY / 2);
	float xScale = yScale / aspect;

	Values[0][0] = xScale;
	Values[0][1] = 0;
	Values[0][2] = 0;
	Values[0][3] = 0;

	Values[1][0] = 0;
	Values[1][1] = yScale;
	Values[1][2] = 0;
	Values[1][3] = 0;

	Values[2][0] = 0;
	Values[2][1] = 0;
	Values[2][2] = zf / (zf - zn);
	Values[2][3] = 1;

	Values[3][0] = 0;
	Values[3][1] = 0;
	Values[3][2] = -zn * zf / (zf - zn);
	Values[3][3] = 0;
	return *this;
}

//----------------------------------------------------------------------------------
//
//---------------------------------------------------------------------------------
Matrix44& Matrix44::PerspectiveFovLH_OpenGL(float ovY, float aspect, float zn, float zf)
{
	float yScale = 1 / tanf(ovY / 2);
	float xScale = yScale / aspect;

	Values[0][0] = xScale;
	Values[0][1] = 0;
	Values[0][2] = 0;
	Values[0][3] = 0;

	Values[1][0] = 0;
	Values[1][1] = yScale;
	Values[1][2] = 0;
	Values[1][3] = 0;

	Values[2][0] = 0;
	Values[2][1] = 0;
	Values[2][2] = zf / (zf - zn);
	Values[2][3] = 1;

	Values[3][0] = 0;
	Values[3][1] = 0;
	Values[3][2] = -2.0f * zn * zf / (zf - zn);
	Values[3][3] = 0;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::OrthographicRH(float width, float height, float zn, float zf)
{
	Values[0][0] = 2 / width;
	Values[0][1] = 0;
	Values[0][2] = 0;
	Values[0][3] = 0;

	Values[1][0] = 0;
	Values[1][1] = 2 / height;
	Values[1][2] = 0;
	Values[1][3] = 0;

	Values[2][0] = 0;
	Values[2][1] = 0;
	Values[2][2] = 1 / (zn - zf);
	Values[2][3] = 0;

	Values[3][0] = 0;
	Values[3][1] = 0;
	Values[3][2] = zn / (zn - zf);
	Values[3][3] = 1;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::OrthographicLH(float width, float height, float zn, float zf)
{
	Values[0][0] = 2 / width;
	Values[0][1] = 0;
	Values[0][2] = 0;
	Values[0][3] = 0;

	Values[1][0] = 0;
	Values[1][1] = 2 / height;
	Values[1][2] = 0;
	Values[1][3] = 0;

	Values[2][0] = 0;
	Values[2][1] = 0;
	Values[2][2] = 1 / (zf - zn);
	Values[2][3] = 0;

	Values[3][0] = 0;
	Values[3][1] = 0;
	Values[3][2] = zn / (zn - zf);
	Values[3][3] = 1;
	return *this;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::Scaling(float x, float y, float z)
{
	memset(Values, 0, sizeof(float) * 16);
	Values[0][0] = x;
	Values[1][1] = y;
	Values[2][2] = z;
	Values[3][3] = 1.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::RotationX(float angle)
{
	float c, s;
	SinCos(angle, s, c);

	Values[0][0] = 1.0f;
	Values[0][1] = 0.0f;
	Values[0][2] = 0.0f;
	Values[0][3] = 0.0f;

	Values[1][0] = 0.0f;
	Values[1][1] = c;
	Values[1][2] = s;
	Values[1][3] = 0.0f;

	Values[2][0] = 0.0f;
	Values[2][1] = -s;
	Values[2][2] = c;
	Values[2][3] = 0.0f;

	Values[3][0] = 0.0f;
	Values[3][1] = 0.0f;
	Values[3][2] = 0.0f;
	Values[3][3] = 1.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::RotationY(float angle)
{
	float c, s;
	SinCos(angle, s, c);

	Values[0][0] = c;
	Values[0][1] = 0.0f;
	Values[0][2] = -s;
	Values[0][3] = 0.0f;

	Values[1][0] = 0.0f;
	Values[1][1] = 1.0f;
	Values[1][2] = 0.0f;
	Values[1][3] = 0.0f;

	Values[2][0] = s;
	Values[2][1] = 0.0f;
	Values[2][2] = c;
	Values[2][3] = 0.0f;

	Values[3][0] = 0.0f;
	Values[3][1] = 0.0f;
	Values[3][2] = 0.0f;
	Values[3][3] = 1.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::RotationZ(float angle)
{
	float c, s;
	SinCos(angle, s, c);

	Values[0][0] = c;
	Values[0][1] = s;
	Values[0][2] = 0.0f;
	Values[0][3] = 0.0f;

	Values[1][0] = -s;
	Values[1][1] = c;
	Values[1][2] = 0.0f;
	Values[1][3] = 0.0f;

	Values[2][0] = 0.0f;
	Values[2][1] = 0.0f;
	Values[2][2] = 1;
	Values[2][3] = 0.0f;

	Values[3][0] = 0.0f;
	Values[3][1] = 0.0f;
	Values[3][2] = 0.0f;
	Values[3][3] = 1.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::Translation(float x, float y, float z)
{
	Indentity();
	Values[3][0] = x;
	Values[3][1] = y;
	Values[3][2] = z;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::RotationAxis(const Vector3D& axis, float angle)
{
	const float c = cosf(angle);
	const float s = sinf(angle);
	const float cc = 1.0f - c;

	Values[0][0] = cc * (axis.X * axis.X) + c;
	Values[0][1] = cc * (axis.X * axis.Y) + (axis.Z * s);
	Values[0][2] = cc * (axis.Z * axis.X) - (axis.Y * s);

	Values[1][0] = cc * (axis.X * axis.Y) - (axis.Z * s);
	Values[1][1] = cc * (axis.Y * axis.Y) + c;
	Values[1][2] = cc * (axis.Y * axis.Z) + (axis.X * s);

	Values[2][0] = cc * (axis.Z * axis.X) + (axis.Y * s);
	Values[2][1] = cc * (axis.Y * axis.Z) - (axis.X * s);
	Values[2][2] = cc * (axis.Z * axis.Z) + c;

	Values[3][0] = 0.0f;
	Values[3][1] = 0.0f;
	Values[3][2] = 0.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
void Matrix44::Quaternion(float x, float y, float z, float w)
{
	float xx = x * x;
	float yy = y * y;
	float zz = z * z;
	float xy = x * y;
	float xz = x * z;
	float yz = y * z;
	float wx = w * x;
	float wy = w * y;
	float wz = w * z;

	Values[0][0] = 1.0f - 2.0f * (yy + zz);
	Values[1][0] = 2.0f * (xy - wz);
	Values[2][0] = 2.0f * (xz + wy);
	Values[3][0] = 0.0f;

	Values[0][1] = 2.0f * (xy + wz);
	Values[1][1] = 1.0f - 2.0f * (xx + zz);
	Values[2][1] = 2.0f * (yz - wx);
	Values[3][1] = 0.0f;

	Values[0][2] = 2.0f * (xz - wy);
	Values[1][2] = 2.0f * (yz + wx);
	Values[2][2] = 1.0f - 2.0f * (xx + yy);
	Values[3][2] = 0.0f;

	Values[0][3] = 0.0f;
	Values[1][3] = 0.0f;
	Values[2][3] = 0.0f;
	Values[3][3] = 1.0f;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::Mul(Matrix44& o, const Matrix44& in1, const Matrix44& in2)
{
	Matrix44 _in1 = in1;
	Matrix44 _in2 = in2;

	for (int i = 0; i < 4; i++)
	{
		for (int j = 0; j < 4; j++)
		{
			float v = 0.0f;
			for (int k = 0; k < 4; k++)
			{
				v += _in1.Values[i][k] * _in2.Values[k][j];
			}
			o.Values[i][j] = v;
		}
	}
	return o;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
Matrix44& Matrix44::Inverse(Matrix44& o, const Matrix44& in)
{
	float a11 = in.Values[0][0];
	float a12 = in.Values[0][1];
	float a13 = in.Values[0][2];
	float a14 = in.Values[0][3];
	float a21 = in.Values[1][0];
	float a22 = in.Values[1][1];
	float a23 = in.Values[1][2];
	float a24 = in.Values[1][3];
	float a31 = in.Values[2][0];
	float a32 = in.Values[2][1];
	float a33 = in.Values[2][2];
	float a34 = in.Values[2][3];
	float a41 = in.Values[3][0];
	float a42 = in.Values[3][1];
	float a43 = in.Values[3][2];
	float a44 = in.Values[3][3];

	/* 行列式の計算 */
	float b11 = +a22 * (a33 * a44 - a43 * a34) - a23 * (a32 * a44 - a42 * a34) + a24 * (a32 * a43 - a42 * a33);
	float b12 = -a12 * (a33 * a44 - a43 * a34) + a13 * (a32 * a44 - a42 * a34) - a14 * (a32 * a43 - a42 * a33);
	float b13 = +a12 * (a23 * a44 - a43 * a24) - a13 * (a22 * a44 - a42 * a24) + a14 * (a22 * a43 - a42 * a23);
	float b14 = -a12 * (a23 * a34 - a33 * a24) + a13 * (a22 * a34 - a32 * a24) - a14 * (a22 * a33 - a32 * a23);

	float b21 = -a21 * (a33 * a44 - a43 * a34) + a23 * (a31 * a44 - a41 * a34) - a24 * (a31 * a43 - a41 * a33);
	float b22 = +a11 * (a33 * a44 - a43 * a34) - a13 * (a31 * a44 - a41 * a34) + a14 * (a31 * a43 - a41 * a33);
	float b23 = -a11 * (a23 * a44 - a43 * a24) + a13 * (a21 * a44 - a41 * a24) - a14 * (a21 * a43 - a41 * a23);
	float b24 = +a11 * (a23 * a34 - a33 * a24) - a13 * (a21 * a34 - a31 * a24) + a14 * (a21 * a33 - a31 * a23);

	float b31 = +a21 * (a32 * a44 - a42 * a34) - a22 * (a31 * a44 - a41 * a34) + a24 * (a31 * a42 - a41 * a32);
	float b32 = -a11 * (a32 * a44 - a42 * a34) + a12 * (a31 * a44 - a41 * a34) - a14 * (a31 * a42 - a41 * a32);
	float b33 = +a11 * (a22 * a44 - a42 * a24) - a12 * (a21 * a44 - a41 * a24) + a14 * (a21 * a42 - a41 * a22);
	float b34 = -a11 * (a22 * a34 - a32 * a24) + a12 * (a21 * a34 - a31 * a24) - a14 * (a21 * a32 - a31 * a22);

	float b41 = -a21 * (a32 * a43 - a42 * a33) + a22 * (a31 * a43 - a41 * a33) - a23 * (a31 * a42 - a41 * a32);
	float b42 = +a11 * (a32 * a43 - a42 * a33) - a12 * (a31 * a43 - a41 * a33) + a13 * (a31 * a42 - a41 * a32);
	float b43 = -a11 * (a22 * a43 - a42 * a23) + a12 * (a21 * a43 - a41 * a23) - a13 * (a21 * a42 - a41 * a22);
	float b44 = +a11 * (a22 * a33 - a32 * a23) - a12 * (a21 * a33 - a31 * a23) + a13 * (a21 * a32 - a31 * a22);

	// 行列式の逆数をかける
	float Det = (a11 * b11) + (a12 * b21) + (a13 * b31) + (a14 * b41);
	if ((-FLT_MIN <= Det) && (Det <= +FLT_MIN))
	{
		o = in;
		return o;
	}

	float InvDet = 1.0f / Det;

	o.Values[0][0] = b11 * InvDet;
	o.Values[0][1] = b12 * InvDet;
	o.Values[0][2] = b13 * InvDet;
	o.Values[0][3] = b14 * InvDet;
	o.Values[1][0] = b21 * InvDet;
	o.Values[1][1] = b22 * InvDet;
	o.Values[1][2] = b23 * InvDet;
	o.Values[1][3] = b24 * InvDet;
	o.Values[2][0] = b31 * InvDet;
	o.Values[2][1] = b32 * InvDet;
	o.Values[2][2] = b33 * InvDet;
	o.Values[2][3] = b34 * InvDet;
	o.Values[3][0] = b41 * InvDet;
	o.Values[3][1] = b42 * InvDet;
	o.Values[3][2] = b43 * InvDet;
	o.Values[3][3] = b44 * InvDet;

	return o;
}

//----------------------------------------------------------------------------------
//
//----------------------------------------------------------------------------------
} // namespace Effekseer
  //----------------------------------------------------------------------------------
  //
  //----------------------------------------------------------------------------------